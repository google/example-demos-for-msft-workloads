<#**
 * Copyright 2023 Google LLC
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

### MANAGEMENT VM CONFIGURATION SCRIPT ### 

#Generate Stage 1 Script

'
$ErrorActionPreference = "SilentlyContinue"

#Disable Scheduled Task for Stage 1
Disable-ScheduledTask -TaskName "Management VM Bootstrap - Stage 1"

#Install RSAT Tools
Install-WindowsFeature RSAT-AD-Tools,RSAT-DNS-Server,GPMC

#Getting Local Admin password and enabling account
$local_admin_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${local_admin_secret_id}) -AsPlainText -Force
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $local_admin_password
Get-LocalUser -Name "Administrator" | Enable-LocalUser

#Download and install SSMS 
(New-Object Net.WebClient).DownloadFile("https://aka.ms/ssmsfullsetup", "C:\SSMS-Setup-ENU.exe")
C:\SSMS-Setup-ENU.exe /install /quiet /norestart

#Wait for Managed AD Domain to come online and then reset Admin password
$ad_status = ((gcloud active-directory domains describe ${managed_ad_domain_name} --format json) | ConvertFrom-Json)[0].state

while ($ad_status -ne "READY") {
    Sleep(60)
    $ad_status = ((gcloud active-directory domains describe ${managed_ad_domain_name} --format json) | ConvertFrom-Json)[0].state
}

#Getting Managed AD Admin Username and Password
Sleep(60)
$managed_ad_admin_user = "${managed_ad_domain_name}" + "\" + ((gcloud active-directory domains describe ${managed_ad_domain_name} --format json) | ConvertFrom-Json)[0].admin
$managed_ad_admin_password = ((((gcloud secrets versions access latest --secret=${managed_ad_admin_secret_id}) -Split "\n")[1]) -Split " ")[2]
$managed_ad_admin_password  = ConvertTo-SecureString -String $managed_ad_admin_password -AsPlainText -Force
$domain_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $managed_ad_admin_user, $managed_ad_admin_password

#Unregister Scheduled Task for Stage 1
Unregister-ScheduledTask -TaskName "Management VM Bootstrap - Stage 1" -Confirm:$false

#Add Instance metadata to mark as ready
gcloud compute instances add-metadata ${mgmt_vm_os_hostname} --zone=${mgmt_vm_zone} --metadata="status"="ready"

#Add SQL Server Management Studio shortcut to Desktop
New-Item -ItemType SymbolicLink -Path "C:\Users\Public\Desktop" -Name "Microsoft SQL Server Management Studio 18.lnk" -Value "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\Ssms.exe"

#Joining Server to ${managed_ad_domain_name} and restarting
Add-Computer -Domain ${managed_ad_domain_name} -Credential $domain_credential -Restart -Force

' | Out-File C:\stage1.ps1

$stage1_taskName = "Management VM Bootstrap - Stage 1"
$s1action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage1.ps1"
$s1trigger = New-ScheduledTaskTrigger -AtStartup

$s1principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s1action -Trigger $s1trigger -Principal $s1principal -TaskName $stage1_taskName
