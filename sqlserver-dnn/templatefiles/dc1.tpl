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

### DOMAIN CONTROLLER CONFIGURATION SCRIPT ### 

#Generate Stage 1 Script
'
$ErrorActionPreference = "Stop"

#Add Bootstrapping Metadata to GCE Instance Metadata
gcloud compute instances add-metadata ${dc1_os_hostname} --zone=${dc1_zone} --metadata=STATUS=BOOTSTRAPPING

#Disable Scheduled Task for Stage 1
Disable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 1"

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${dc1_os_hostname} --zone=${dc1_zone} --metadata=STATUS=INSTALLING_ADDS_ROLE

#Install required Windows features
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

#Install Chrome
Start-BitsTransfer -Source "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -Destination "C:\chrome_installer.exe"
Start-Process "C:\chrome_installer.exe" -ArgumentList "/silent /install" -Wait

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${dc1_os_hostname} --zone=${dc1_zone} --metadata=STATUS=SETTING_PASSWORDS

$local_admin_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${local_admin_secret_id}) -AsPlainText -Force
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $local_admin_password
Get-LocalUser -Name "Administrator" | Enable-LocalUser

#Get DSRM Password
$adds_dsrm_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${adds_dsrm_secret_id}) -AsPlainText -Force

#Enable Scheduled Task for Stage 2
Enable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 1
Unregister-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 1" -Confirm:$false

#Add Admin credentials to Secret Manager
$ad_admin_user = "administrator"
$ad_admin_password = (gcloud secrets versions access latest --secret=${local_admin_secret_id})
$ad_admin_cred = ("Admin Username: "+ "${ad_domain_name}" + "\" + $ad_admin_user + " `nAdmin Password: " + $ad_admin_password)
$ad_admin_cred | gcloud secrets versions add ${ad_admin_secret_id} --data-file=-

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${dc1_os_hostname} --zone=${dc1_zone} --metadata=STATUS=INSTALLING_DOMAIN

#Install Domain
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "${ad_domain_name}" `
-DomainNetbiosName "${ad_domain_netbios}" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-SafeModeAdministratorPassword $adds_dsrm_password `
-Force:$true

' | Out-File C:\stage1.ps1

#Generate Stage 2 Script
'
$ErrorActionPreference = "SilentlyContinue"

#Disable Scheduled Task for Stage 2
Disable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 2"

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${dc1_os_hostname} --zone=${dc1_zone} --metadata=STATUS=CREATING_AD_OU

#Wait for Domain Services to finish loading
Start-Sleep (60)

#Get Domain Information
$Domain = (Get-ADDomain).DNSRoot
$BaseDN = (Get-ADDomain).DistinguishedName

#Create OU Structure
New-ADOrganizationalUnit -Name "Google Cloud" -Path $BaseDN -ProtectedFromAccidentalDeletion $False
$GCPDN = (Get-ADOrganizationalUnit -Filter ''Name -eq "Google Cloud"'').DistinguishedName
New-ADOrganizationalUnit -Name "Users" -Path $GCPDN -ProtectedFromAccidentalDeletion $False
New-ADOrganizationalUnit -Name "Groups" -Path $GCPDN -ProtectedFromAccidentalDeletion $False
New-ADOrganizationalUnit -Name "Service Accounts" -Path $GCPDN -ProtectedFromAccidentalDeletion $False

#Create Service Accounts
$ServiceAccountsDN = (Get-ADOrganizationalUnit -Filter ''Name -eq "Service Accounts"'' -SearchBase $GCPDN).DistinguishedName
$SQLServiceAccountPassword = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${sql_service_account_secret_id}) -AsPlainText -Force
$WebServiceAccountPassword = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${web_service_account_secret_id}) -AsPlainText -Force
New-ADUser -Name "${sql_service_account_name}" -Description "SQL Server Service Account" -Path $ServiceAccountsDN -AccountPassword $SQLServiceAccountPassword -Enabled $true -PasswordNeverExpires $true
New-ADUser -Name "${web_service_account_name}" -Description "Web Server Service Account" -Path $ServiceAccountsDN -AccountPassword $WebServiceAccountPassword -Enabled $true -PasswordNeverExpires $true

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${dc1_os_hostname} --zone=${dc1_zone} --metadata=STATUS=READY

#Unregister Scheduled Task for Stage 2
Unregister-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 2" -Confirm:$false

' | Out-File C:\stage2.ps1

$stage1_taskName = "Domain Controller Bootstrap - Stage 1"
$s1action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage1.ps1"
$s1trigger = New-ScheduledTaskTrigger -AtStartup

$s1principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s1action -Trigger $s1trigger -Principal $s1principal -TaskName $stage1_taskName

$stage2_taskName = "Domain Controller Bootstrap - Stage 2"
$s2action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage2.ps1"
$s2trigger = New-ScheduledTaskTrigger -AtStartup

$s2principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s2action -Trigger $s2trigger -Principal $s2principal -TaskName $stage2_taskName
Disable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 2"

#Disable Server Manager Startup
Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask