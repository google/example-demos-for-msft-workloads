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

### JUMPBOX CONFIGURATION SCRIPT ### 

#Generate Stage 1 Script

'
$ErrorActionPreference = "SilentlyContinue"

#Disable Scheduled Task for Stage 1
Disable-ScheduledTask -TaskName "Jumpbox VM Bootstrap - Stage 1"

#Getting Local Admin password and enabling account
$local_admin_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${local_admin_secret_id}) -AsPlainText -Force
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $local_admin_password
Get-LocalUser -Name "Administrator" | Enable-LocalUser

#Unregister Scheduled Task for Stage 1
Unregister-ScheduledTask -TaskName "Jumpbox VM Bootstrap - Stage 1" -Confirm:$false

#Add Instance metadata to mark as ready
gcloud compute instances add-metadata ${jumpbox_os_hostname} --zone=${jumpbox_vm_zone} --metadata="status"="ready"

' | Out-File C:\stage1.ps1

$stage1_taskName = "Management VM Bootstrap - Stage 1"
$s1action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage1.ps1"
$s1trigger = New-ScheduledTaskTrigger -AtStartup

$s1principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s1action -Trigger $s1trigger -Principal $s1principal -TaskName $stage1_taskName

#Generate instructions to retrieve passwords
'
#########################
### P A S S W O R D S ###
#########################

On-Prem Environment
===================
Connection Name: on-prem-dc (RDP file on Desktop)
Password       : (see below)
 Do one of the following to retrieve the password
 - Option #1: Navigate to Cloud Console > Security > Secrets Manager > ${on_prem_ad_admin_secret_id}
 - Option #2: Run the following command from Powershell to see the Credentials
            > gcloud secrets versions access latest --secret=${on_prem_ad_admin_secret_id}

Managed AD Environment
======================
Connection Name: mgmt-vm-managed-ad (RDP file on Desktop)
Password       : (see below)
 Do one of the following to retrieve the password
 - Option #1: Navigate to Cloud Console > Security > Secrets Manager > ${managed_ad_admin_secret_id}
 - Option #2: Run the following command from Powershell to see the Credentials
            > gcloud secrets versions access latest --secret=${managed_ad_admin_secret_id}
' | Out-File C:\Users\Public\Desktop\Passwords-Readme.txt


#Generate RDP file for dc1
'
screen mode id:i:2
use multimon:i:0
desktopwidth:i:800
desktopheight:i:600
session bpp:i:32
winposstr:s:0,3,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
username:s:${on_prem_ad_domain_netbios}\administrator
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:${dc1_ip_address}
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectwebauthn:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
enablerdsaadauth:i:0
' | Out-File C:\Users\Public\Desktop\on-prem-dc.rdp 

#Generate RDP file for mgmt-vm
'
screen mode id:i:2
use multimon:i:0
desktopwidth:i:800
desktopheight:i:600
session bpp:i:32
winposstr:s:0,3,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
username:s:${managed_ad_domain_netbios}\setupadmin
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:${mgmt_vm_ip_address}
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectwebauthn:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
enablerdsaadauth:i:0
' | Out-File C:\Users\Public\Desktop\mgmt-vm-managed-ad.rdp 
