<#**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *#>

### SQL SERVER CONFIGURATION SCRIPT ### 

#Generate Stage 1 Script
'
$ErrorActionPreference = "Stop"

#Wait for OS to initialize
Start-Sleep (60)

#Add Bootstrapping Metadata to GCE Instance Metadata
gcloud compute instances add-metadata ${sql2_os_hostname} --zone=${sql2_zone} --metadata=STATUS=BOOTSTRAPPING

#Disable Scheduled Task for Stage 1
Disable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 1"

# Install required Windows features
Install-WindowsFeature Failover-Clustering -IncludeManagementTools
Install-WindowsFeature RSAT-AD-PowerShell

#Open Windows Firewall Ports for SQL Server AlwaysOn
netsh advfirewall firewall add rule name="Allow SQL Server" dir=in action=allow protocol=TCP localport=1433
netsh advfirewall firewall add rule name="Allow SQL Server replication" dir=in action=allow protocol=TCP localport=5022
netsh advfirewall firewall add rule name="Allow SQL Server DNN Listener" dir=in action=allow protocol=TCP localport=${dnn_listener_port}

#Install Chrome
Start-BitsTransfer -Source "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -Destination "C:\chrome_installer.exe"
Start-Process "C:\chrome_installer.exe" -ArgumentList "/silent /install" -Wait

#Enable Local Administrator
$local_admin_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${local_admin_secret_id}) -AsPlainText -Force
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $local_admin_password
Get-LocalUser -Name "Administrator" | Enable-LocalUser

#Enable Scheduled Task for Stage 2
Enable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 1
Unregister-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 1" -Confirm:$false

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${sql2_os_hostname} --zone=${sql2_zone} --metadata=STATUS=DOMAIN_READY_CHECK

#Check if Domain Controller is ready and add this Server to Domain
$DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
while($DomainStatus -ne "READY")
    {
        Start-Sleep(5)
        $DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
    }

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${sql2_os_hostname} --zone=${sql2_zone} --metadata=STATUS=JOINING_DOMAIN

$ad_admin_user = "administrator"
$ad_admin_username = "${ad_domain_netbios}" + "\" + $ad_admin_user
$domain_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ad_admin_username, $local_admin_password
Add-Computer -Domain ${ad_domain_name} -Credential $domain_credential -Restart -Force

' | Out-File C:\stage1.ps1

#Generate Stage 2 Script
'
#$ErrorActionPreference = "SilentlyContinue"

#Wait for OS to initialize
Start-Sleep (60)

#Disable Scheduled Task for Stage 2
Disable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 2
#Unregister-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2" -Confirm:$false

#Set DNS Suffix and Register DNS Client
Set-DNSClient -InterfaceAlias "Ethernet" -ConnectionSpecificSuffix "${ad_domain_name}"
Register-DnsClient

#Change SQL Server Service Logon Account
pwsh C:\sqlsvc.ps1

#Rename SQL Server Instance
$renameinstance = "EXEC sp_dropserver @server=@@SERVERNAME;
GO
EXEC sp_addserver ''${sql2_os_hostname}'', local;
GO"
sqlcmd -Q $renameinstance
Restart-Service -Name MSSQLSERVER

#Add SQL Server Service Account to Local Administrators
Add-LocalGroupMember -Group "Administrators" -Member "${ad_domain_netbios}\${sql_service_account}"

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${sql2_os_hostname} --zone=${sql2_zone} --metadata=STATUS=READY

' | Out-File C:\stage2.ps1

$stage1_taskName = "SQL Server Bootstrap - Stage 1"
$s1action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage1.ps1"
$s1trigger = New-ScheduledTaskTrigger -AtStartup

$s1principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s1action -Trigger $s1trigger -Principal $s1principal -TaskName $stage1_taskName

$stage2_taskName = "SQL Server Bootstrap - Stage 2"
$s2action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage2.ps1"
$s2trigger = New-ScheduledTaskTrigger -AtStartup

$s2principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s2action -Trigger $s2trigger -Principal $s2principal -TaskName $stage2_taskName
Disable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2"

#Disable Server Manager Startup
Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask

'
$sql_username = "${ad_domain_netbios}\${sql_service_account}"
$sql_user_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${sql_service_account_secret_id}) -AsPlainText -Force
$sql_user_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sql_username, $sql_user_password
Set-Service -Name MSSQLSERVER -Credential $sql_user_credential
Restart-Service -Name MSSQLSERVER
' | Out-File C:\sqlsvc.ps1