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

### WEB SERVER CONFIGURATION SCRIPT ### 

#Generate Stage 1 Script
'
$ErrorActionPreference = "Stop"

#Wait for OS to initialize
Start-Sleep (60)

#Add Bootstrapping Metadata to GCE Instance Metadata
gcloud compute instances add-metadata ${web1_os_hostname} --zone=${web1_zone} --metadata=STATUS=BOOTSTRAPPING

#Disable Scheduled Task for Stage 1
Disable-ScheduledTask -TaskName "Web Server Bootstrap - Stage 1"

#Install required Windows features
#Install-WindowsFeature Web-Server,Web-App-Dev,Web-Asp-Net,Web-Asp-Net45,Web-Net-Ext45,NET-Framework-Core,NET-Framework-45-ASPNET -IncludeManagementTools
Install-WindowsFeature Web-Default-Doc, Web-Filtering, Web-Windows-Auth, Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext, Web-ISAPI-Filter, NET-Framework-Core, NET-Framework-45-Core, NET-Framework-45-ASPNET, NET-WCF-TCP-PortSharing45 -IncludeManagementTools
Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication -PSPath IIS:\ -name enabled -value true
Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -PSPath IIS:\ -name enabled -value true

#Install Chrome
Start-BitsTransfer -Source "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -Destination "C:\chrome_installer.exe"
Start-Process "C:\chrome_installer.exe" -ArgumentList "/silent /install" -Wait

#Install SQL Server Management Studio
Start-BitsTransfer -Source "https://aka.ms/ssmsfullsetup" -Destination "C:\ssms_setup.exe"
Start-Process "C:\ssms_setup.exe" -ArgumentList "/install /quiet" -Wait
Copy-Item "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft SQL Server Tools 19\SQL Server Management Studio 19.lnk" "C:\Users\Public\Desktop"

#Enable Local Administrator
$local_admin_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${local_admin_secret_id}) -AsPlainText -Force
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $local_admin_password
Get-LocalUser -Name "Administrator" | Enable-LocalUser

#Enable Scheduled Task for Stage 2
Enable-ScheduledTask -TaskName "Web Server Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 1
Unregister-ScheduledTask -TaskName "Web Server Bootstrap - Stage 1" -Confirm:$false

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${web1_os_hostname} --zone=${web1_zone} --metadata=STATUS=DOMAIN_READY_CHECK

#Check if Domain Controller is ready and add this Server to Domain
$DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
while($DomainStatus -ne "READY")
    {
        Start-Sleep(5)
        $DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
    }

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${web1_os_hostname} --zone=${web1_zone} --metadata=STATUS=JOINING_DOMAIN

$ad_admin_user = "administrator"
$ad_admin_username = "${ad_domain_netbios}" + "\" + $ad_admin_user
$domain_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ad_admin_username, $local_admin_password
Add-Computer -Domain ${ad_domain_name} -Credential $domain_credential -Restart -Force

' | Out-File C:\stage1.ps1

#Generate Stage 2 Script
'
$ErrorActionPreference = "SilentlyContinue"

#Disable Scheduled Task for Stage 2
Disable-ScheduledTask -TaskName "Web Server Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 2
Unregister-ScheduledTask -TaskName "Web Server Bootstrap - Stage 2" -Confirm:$false

#Set DNS Suffix and Register DNS Client
Set-DNSClient -InterfaceAlias "Ethernet" -ConnectionSpecificSuffix "${ad_domain_name}"
Register-DnsClient

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${web1_os_hostname} --zone=${web1_zone} --metadata=STATUS=CONFIGURING_WEBAPP

#Configure Web App Pool
Import-Module WebAdministration
$AppPoolName = "DefaultAppPool"
$websvc = "${ad_domain_netbios}\${web_service_account}"
$websvcpassword = gcloud secrets versions access latest --secret=${web_service_secret_id}
Stop-WebAppPool -Name "DefaultAppPool"
Set-ItemProperty IIS:\AppPools\$AppPoolName -name processModel -value @{userName=$websvc;password=$websvcpassword;identitytype=3}
Start-Sleep(5)
Start-WebAppPool -Name "DefaultAppPool"

#Download Sample Web App
Start-BitsTransfer -Source "${sample_website_url}" -Destination "C:\samplewebapp.zip"

#Extract Web App
Expand-Archive C:\samplewebapp.zip C:\inetpub\wwwroot\

#Update Connection String
$listenername = "${dnn_listener_name}"
$listenerport = "${dnn_listener_port}"
Set-WebConfigurationProperty -pspath "IIS:\Sites\Default Web Site\" -Filter "/connectionStrings/add[@name=''SchoolContext'']" `
-Name ''connectionString'' `
-Value "Data Source=$listenername,$listenerport;MultiSubnetFailover=True;Initial Catalog=ContosoUniversity;Integrated Security=SSPI;"
Stop-Website -Name "Default Web Site"
Start-WebSite -Name "Default Web Site"


#Restart Website
Stop-Website -Name "Default Web Site"
Start-Website -Name "Default Web Site"

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${web1_os_hostname} --zone=${web1_zone} --metadata=STATUS=READY

' | Out-File C:\stage2.ps1

$stage1_taskName = "Web Server Bootstrap - Stage 1"
$s1action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "C:\stage1.ps1"
$s1trigger = New-ScheduledTaskTrigger -AtStartup

$s1principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s1action -Trigger $s1trigger -Principal $s1principal -TaskName $stage1_taskName

$stage2_taskName = "Web Server Bootstrap - Stage 2"
$s2action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "C:\stage2.ps1"
$s2trigger = New-ScheduledTaskTrigger -AtStartup

$s2principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s2action -Trigger $s2trigger -Principal $s2principal -TaskName $stage2_taskName
Disable-ScheduledTask -TaskName "Web Server Bootstrap - Stage 2"

#Disable Server Manager Startup
Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask