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

### JUMPBOX SERVER CONFIGURATION SCRIPT ### 

#Generate Stage 1 Script
'
$ErrorActionPreference = "Stop"

#Wait for OS to initialize
Start-Sleep (60)

#Add Bootstrapping Metadata to GCE Instance Metadata
gcloud compute instances add-metadata ${jumpbox_os_hostname} --zone=${jumpbox_zone} --metadata=STATUS=BOOTSTRAPPING

#Disable Scheduled Task for Stage 1
Disable-ScheduledTask -TaskName "Jumpbox Server Bootstrap - Stage 1"

#Install Chrome
Start-BitsTransfer -Source "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -Destination "C:\chrome_installer.exe"
Start-Process "C:\chrome_installer.exe" -ArgumentList "/silent /install" -Wait

#Enable Local Administrator
$local_admin_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${local_admin_secret_id}) -AsPlainText -Force
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password $local_admin_password
Get-LocalUser -Name "Administrator" | Enable-LocalUser

#Enable Scheduled Task for Stage 2
Enable-ScheduledTask -TaskName "Jumpbox Server Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 1
Unregister-ScheduledTask -TaskName "Jumpbox Server Bootstrap - Stage 1" -Confirm:$false

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${jumpbox_os_hostname} --zone=${jumpbox_zone} --metadata=STATUS=DOMAIN_READY_CHECK

#Check if Domain Controller is ready and add this Server to Domain
$DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
while($DomainStatus -ne "READY")
    {
        Start-Sleep(5)
        $DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
    }

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${jumpbox_os_hostname} --zone=${jumpbox_zone} --metadata=STATUS=JOINING_DOMAIN

$ad_admin_user = "administrator"
$ad_admin_username = "${ad_domain_netbios}" + "\" + $ad_admin_user
$domain_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ad_admin_username, $local_admin_password
Add-Computer -Domain ${ad_domain_name} -Credential $domain_credential -Restart -Force

' | Out-File C:\stage1.ps1

#Generate Stage 2 Script
'
#$ErrorActionPreference = "SilentlyContinue"

#Disable Scheduled Task for Stage 2
Disable-ScheduledTask -TaskName "Jumpbox Server Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 2
#Unregister-ScheduledTask -TaskName "Jumpbox Server Bootstrap - Stage 2" -Confirm:$false

#Set DNS Suffix and Register DNS Client
Set-DNSClient -InterfaceAlias "Ethernet" -ConnectionSpecificSuffix "${ad_domain_name}"
Register-DnsClient

#Clean up files on Public Desktop
Get-ChildItem -Path C:\Users\Public\Desktop | Where-Object {$_.Extension -notin ".rdp", ".txt"} | Remove-Item

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${jumpbox_os_hostname} --zone=${jumpbox_zone} --metadata=STATUS=READY

' | Out-File C:\stage2.ps1

$stage1_taskName = "Jumpbox Server Bootstrap - Stage 1"
$s1action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage1.ps1"
$s1trigger = New-ScheduledTaskTrigger -AtStartup

$s1principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s1action -Trigger $s1trigger -Principal $s1principal -TaskName $stage1_taskName

$stage2_taskName = "Jumpbox Server Bootstrap - Stage 2"
$s2action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage2.ps1"
$s2trigger = New-ScheduledTaskTrigger -AtStartup

$s2principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s2action -Trigger $s2trigger -Principal $s2principal -TaskName $stage2_taskName
Disable-ScheduledTask -TaskName "Jumpbox Server Bootstrap - Stage 2"

#Disable Server Manager Startup
Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask

#Generate RDP File for dc1
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
username:s:example\administrator
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:dc1
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
' | Out-File C:\Users\Public\Desktop\dc1.rdp 

#Generate RDP File for SQL1
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
username:s:example\administrator
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:sql1
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
' | Out-File C:\Users\Public\Desktop\sql1.rdp

#Generate RDP File for SQL2
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
username:s:example\administrator
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:sql2
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
' | Out-File C:\Users\Public\Desktop\sql2.rdp

#Generate RDP File for Web1
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
username:s:example\administrator
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:web1
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
' | Out-File C:\Users\Public\Desktop\web1.rdp

#Generate RDP File for Witness
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
username:s:example\administrator
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:witness
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
' | Out-File C:\Users\Public\Desktop\witness.rdp

#Generate instructions to retrieve passwords
'
###############################
###  C R E D E N T I A L S  ###
###############################

All Servers are already joined to the ${ad_domain_name} Domain.

To access the different Servers do the following:

1. Open the Command Prompt or Powershell

2. Run the following command
   > gcloud secrets versions access latest --secret=${ad_admin_secret_id}

   Note: The Service Account used to create the Servers are already authorized to access the Secret.

   You can also navigate to Cloud Console > Security > Secrets Manager > ${ad_admin_secret_id}

3. Copy the password

4. Double click on the Server RDP file on the Desktop (for example: dc1) and when prompted, supply the password
' | Out-File "C:\Users\Public\Desktop\Readme.txt"
