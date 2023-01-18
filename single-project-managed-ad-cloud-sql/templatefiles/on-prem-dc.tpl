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

### ON-PREM DOMAIN CONTROLLER CONFIGURATION SCRIPT ### 

#Generate Stage 1 Script
'
$ErrorActionPreference = "Stop"

#Disable Scheduled Task for Stage 1
Disable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 1"

# Install required Windows features
Write-Output "Installing Active Directory Domain Services"
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Write-Output "Setting local Administrator password & enabling the account"
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
$on_prem_ad_admin_user = "administrator"
$on_prem_ad_admin_password = (gcloud secrets versions access latest --secret=${local_admin_secret_id})
$on_prem_ad_admin_cred = ("Admin Username: "+ "${on_prem_ad_domain_name}" + "\" + $on_prem_ad_admin_user + " `nAdmin Password: " + $on_prem_ad_admin_password)
$on_prem_ad_admin_cred | gcloud secrets versions add ${on_prem_ad_admin_secret_id} --data-file=-

#Install Domain
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "${on_prem_ad_domain_name}" `
-DomainNetbiosName "${on_prem_ad_domain_netbios}" `
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

$Domain = (Get-ADDomain).DNSRoot
$UserPassword = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${user_password_secret_id}) -AsPlainText -Force
$BaseDN = (Get-ADDomain).DistinguishedName

function Add-CorpOU ($BaseDN) {
    $CorpUserList = "Albert Einstein", `
                    "Marie Curie", `
                    "Neil deGrasse Tyson", `
                    "George Washington Carver", `
                    "Charles Darwin", `
                    "Nikola Tesla", `
                    "Stephen Hawking", `
                    "Katherine Johnson", `
                    "Grace Hopper", `
                    "Mae Jemison", `
                    "Dorothy Vaughan", `
                    "Mary Jackson", `
                    "Srinivasa Ramanujan", `
                    "Subrahmanyan Chandrasekhar", `
                    "Leonardo Pisano Bigollo", `
                    "Bill Nye", `
                    "Isaac Newton", `
                    "Florence Nightingale", `
                    "Louis Pasteur", `
                    "Chen-Ning Yang", `
                    "Susumu Tonegawa", `
                    "Katsuko Saruhashi"


    New-ADOrganizationalUnit -Name "Corp" -Path $BaseDN -ProtectedFromAccidentalDeletion $False
    $CorpDN = (Get-ADOrganizationalUnit -Filter ''Name -eq "Corp"'').DistinguishedName
    
    New-ADOrganizationalUnit -Name "IT" -Path $CorpDN -ProtectedFromAccidentalDeletion $False

    $ITDN = (Get-ADOrganizationalUnit -Filter ''Name -eq "IT"'').DistinguishedName
    New-ADOrganizationalUnit -Name "Users" -Path $ITDN -ProtectedFromAccidentalDeletion $False
    New-ADOrganizationalUnit -Name "Groups" -Path $ITDN -ProtectedFromAccidentalDeletion $False
    New-ADOrganizationalUnit -Name "Service Accounts" -Path $ITDN -ProtectedFromAccidentalDeletion $False

    $CorpITUsersDN = (Get-ADOrganizationalUnit -Filter ''Name -eq "Users"'' -SearchBase $ITDN).DistinguishedName
    
    Add-Users -UserList $CorpUserList -DN $CorpITUsersDN
}

function Add-Users ([string[]]$UserList,$DN) { 

    For ($User=0; $User -lt $UserList.Length; $User++) {
        $FullName = $UserList[$User]
        $GivenName = $UserList[$User].Split('' '') | Select-Object -First 1
        $Surname = $UserList[$User].Split('' '',2) | Select-Object -Last 1
        $LastName = $UserList[$User].Split('' '') | Select-Object -Last 1

        $SAMAcctName = "$GivenName.$LastName"
        If ($SAMAcctName.Length -ge 20) {
            $SAMAcctName = $SAMAcctName.Substring(0,20)
        } 
        
        New-ADUser -Name $FullName `
            -GivenName $GivenName `
            -Surname $Surname `
            -SamAccountName $SAMAcctName `
            -UserPrincipalName "$GivenName.$LastName@$Domain" `
            -EmailAddress "$GivenName.$LastName@$Domain" `
            -AccountPassword ($UserPassword) `
            -Path $DN `
            -Enabled $true
        
    }
}

Add-CorpOU -BaseDN $BaseDN

#Unregister Scheduled Task for Stage 2
Unregister-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 2" -Confirm:$false

#Enable Scheduled Task for Stage 3
Enable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 3"

#Start Scheduled Task for Stage 3
Start-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 3"
' | Out-File C:\stage2.ps1

#Generate Script for Stage 3

'
$ErrorActionPreference = "SilentlyContinue"

#Disable Scheduled Task for Stage 2
Disable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 3"

#Add Conditional Forwarder for Managed AD
Add-DnsServerConditionalForwarderZone -Name "${managed_ad_domain_name}" `
    -ReplicationScope "Forest" `
    -MasterServers (gcloud compute addresses list --filter=''purpose="DNS_RESOLVER"'' --format=''json[no-heading](address, subnetwork)''| ConvertFrom-Json)[0].address

#Wait for Managed AD Domain to come online and then reset Admin password
$ad_status = ((gcloud active-directory domains describe ${managed_ad_domain_name} --format json) | ConvertFrom-Json)[0].state

while ($ad_status -ne "READY") {
    Sleep(30)
    $ad_status = ((gcloud active-directory domains describe ${managed_ad_domain_name} --format json) | ConvertFrom-Json)[0].state
}

#Reset Admin password for Managed AD
$managed_ad_admin_user =  ((gcloud active-directory domains describe ${managed_ad_domain_name} --format json) | ConvertFrom-Json)[0].admin
$managed_ad_admin_password = ((gcloud active-directory domains reset-admin-password ${managed_ad_domain_name} --project ${project_name} --quiet) -Split " ")[1]
$managed_ad_admin_cred = ("Admin Username: " + "${managed_ad_domain_netbios}" + "\" + $managed_ad_admin_user + " `nAdmin Password: " + $managed_ad_admin_password)
$managed_ad_admin_cred | gcloud secrets versions add ${managed_ad_admin_secret_id} --data-file=-

#Iniate Trust creation from ${on_prem_ad_domain_name}
$managed_ad_domain_name = "${managed_ad_domain_name}"
$adds_trust_password = gcloud secrets versions access latest --secret=${adds_trust_password_secret_id}

#Build Objects for each AD Forest
$on_prem_ad_Forest = [System.DirectoryServices.ActiveDirectory.Forest]::getCurrentForest()
$managed_ad_Forest = [System.DirectoryServices.ActiveDirectory.Forest]::getForest([System.DirectoryServices.ActiveDirectory.DirectoryContext]::new("Forest","${managed_ad_domain_name}","$managed_ad_admin_user","$managed_ad_admin_password"))

if ($managed_ad_Forest.ApplicationPartitions[0] -notlike "DC=ForestDnsZones*") {
    $managed_ad_admin_password = ((gcloud active-directory domains reset-admin-password ${managed_ad_domain_name} --project ${project_name} --quiet) -Split " ")[1]
    $managed_ad_admin_cred = ("Admin Username: " + "${managed_ad_domain_netbios}" + "\" + $managed_ad_admin_user + " `nAdmin Password: " + $managed_ad_admin_password)
    $managed_ad_admin_cred | gcloud secrets versions add ${managed_ad_admin_secret_id} --data-file=-
    Sleep(5)
    $on_prem_ad_Forest = [System.DirectoryServices.ActiveDirectory.Forest]::getCurrentForest()
    $managed_ad_Forest = [System.DirectoryServices.ActiveDirectory.Forest]::getForest([System.DirectoryServices.ActiveDirectory.DirectoryContext]::new("Forest","${managed_ad_domain_name}","$managed_ad_admin_user","$managed_ad_admin_password"))
}

#Create Trust on ${on_prem_ad_domain_name} side only
$on_prem_ad_Forest.CreateLocalSideOfTrustRelationship($managed_ad_Forest, "Inbound" , $adds_trust_password)

#Add Instance metadata to mark as ready
gcloud compute instances add-metadata ${dc1_os_hostname} --zone=${dc1_zone} --metadata="status"="ready"

#Unregister Scheduled Task for Stage 3
Unregister-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 3" -Confirm:$false
' | Out-File C:\stage3.ps1

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

$stage3_taskName = "Domain Controller Bootstrap - Stage 3"
$s3action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage3.ps1"
$s3trigger = New-ScheduledTaskTrigger -AtStartup

$s3principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s3action -Trigger $s3trigger -Principal $s3principal -TaskName $stage3_taskName
Disable-ScheduledTask -TaskName "Domain Controller Bootstrap - Stage 3"

