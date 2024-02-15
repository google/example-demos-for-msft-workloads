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
gcloud compute instances add-metadata ${sql1_os_hostname} --zone=${sql1_zone} --metadata=STATUS=BOOTSTRAPPING

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

#Enable Scheduled Task for Stage 2 Skycrane
Enable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2 Skycrane"

#Unregister Scheduled Task for Stage 1
Unregister-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 1" -Confirm:$false

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${sql1_os_hostname} --zone=${sql1_zone} --metadata=STATUS=DOMAIN_READY_CHECK

#Check if Domain Controller is ready and add this Server to Domain
$DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
while($DomainStatus -ne "READY")
    {
        Start-Sleep(5)
        $DomainStatus = gcloud compute instances describe ${dc1_os_hostname} --zone=${dc1_zone} --format="value[](metadata.items.STATUS)"
    }

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${sql1_os_hostname} --zone=${sql1_zone} --metadata=STATUS=JOINING_DOMAIN

$ad_admin_user = "administrator"
$ad_admin_username = "${ad_domain_netbios}" + "\" + $ad_admin_user
$domain_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ad_admin_username, $local_admin_password

Add-Computer -Domain ${ad_domain_name} -Credential $domain_credential -Restart -Force

' | Out-File C:\stage1.ps1

#Generate Stage 2 Script Skycrane
'
$ErrorActionPreference = "SilentlyContinue"

#Disable Scheduled Task for Stage 2 Skycrane
Disable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2 Skycrane"

#Unregister Scheduled Task for Stage 2 Skycrane
Unregister-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2 Skycrane" -Confirm:$false

#Get Domain Credentials
$local_admin_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${local_admin_secret_id}) -AsPlainText -Force
$ad_admin_user = "administrator"
$ad_admin_username = "${ad_domain_netbios}" + "\" + $ad_admin_user
$domain_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ad_admin_username, $local_admin_password
$secure_domain_password = $domain_credential.GetNetworkCredential().Password

#Register Scheduled Task with Domain Credentials
$stage2_taskName = "SQL Server Bootstrap - Stage 2"
$s2action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\stage2.ps1"
$s2trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $s2action -Trigger $s2trigger -TaskName $stage2_taskName -User $ad_admin_username -Password $secure_domain_password
Start-ScheduledTask -TaskName $stage2_taskName
' | Out-File C:\stage2skycrane.ps1

#Generate Stage 2 Script
'
$ErrorActionPreference = "SilentlyContinue"

#Wait for OS to initialize
Start-Sleep (60)

#Disable Scheduled Task for Stage 2
Disable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2"

#Unregister Scheduled Task for Stage 2
Unregister-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2" -Confirm:$false

#Set DNS Suffix and Register DNS Client
Set-DNSClient -InterfaceAlias "Ethernet" -ConnectionSpecificSuffix "${ad_domain_name}"
Register-DnsClient

#Change SQL Server Service Logon Account
pwsh C:\sqlsvc.ps1

#Rename SQL Server Instance
$renameinstance = "EXEC sp_dropserver @server=@@SERVERNAME;
GO
EXEC sp_addserver ''${sql1_os_hostname}'', local;
GO"
sqlcmd -Q $renameinstance
Restart-Service -Name MSSQLSERVER

#Add SQL Server Service Account to Local Administrators
Add-LocalGroupMember -Group "Administrators" -Member "${ad_domain_netbios}\${sql_service_account}"

#Create WSFC Cluster
$sql2Check = Test-NetConnection ${sql2_os_hostname} -Port 1433
$quorumCheck = Get-SMBShare -CIMSession "${witness_os_hostname}" -Name "QWitness"
$Error > C:\error.txt 

while (($sql2Check -eq "Failure") -and !$quorumCheck) {
  Start-Sleep (5)
  $sql2Check = Test-NetConnection ${sql2_os_hostname} -Port 1433
  $quorumCheck = Get-SMBShare -CIMSession "${witness_os_hostname}" -Name "QWitness"
}

New-Cluster -Name sql-cluster -Node ${sql1_os_hostname},${sql2_os_hostname} -NoStorage -StaticAddress ${wsfc_cluster_ip}
$Error >> C:\error.txt

Set-ClusterQuorum -FileShareWitness \\${witness_os_hostname}\QWitness

Enable-SqlAlwaysOn -ServerInstance ${sql1_os_hostname} -Force
Enable-SqlAlwaysOn -ServerInstance ${sql2_os_hostname} -Force

#Download Sample Database
#Start-BitsTransfer -Source "${sample_database_url}" -Destination "C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\ContosoUniversity.bak"
Invoke-WebRequest -Uri "${sample_database_url}" -Outfile "C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\ContosoUniversity.bak"

#Restore Database and prepare for AlwaysOn Availability Group
$restoredb = "USE [master];
RESTORE DATABASE [ContosoUniversity] FROM  DISK = N''C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\ContosoUniversity.bak'' WITH  FILE = 1,  NOUNLOAD,  STATS = 5;
GO
ALTER DATABASE [bookshelf] SET RECOVERY FULL;
GO
BACKUP DATABASE bookshelf to disk = ''C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\CU.bak'' WITH INIT;
GO"
sqlcmd -Q $restoredb

#Build AlwaysOn Availability Group without Listener
$buildag = ":Connect ${sql1_os_hostname}
CREATE ENDPOINT [Hadr_endpoint]
	STATE=STARTED
	AS TCP (LISTENER_PORT=5022)
	FOR DATABASE_MIRRORING (ROLE=ALL, ENCRYPTION = REQUIRED ALGORITHM AES)
GO

:Connect ${sql2_os_hostname}
CREATE ENDPOINT [Hadr_endpoint]
	STATE=STARTED
	AS TCP (LISTENER_PORT=5022)
	FOR DATABASE_MIRRORING (ROLE=ALL, ENCRYPTION = REQUIRED ALGORITHM AES)
GO

:Connect ${sql1_os_hostname}
IF (SELECT state FROM sys.endpoints WHERE name = N''Hadr_endpoint'') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END
GO

use [master]
GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [${ad_domain_netbios}\${sql_service_account}]
GO

:Connect ${sql1_os_hostname}
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name=''AlwaysOn_health'')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name=''AlwaysOn_health'')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END
GO

:Connect ${sql2_os_hostname}
IF (SELECT state FROM sys.endpoints WHERE name = N''Hadr_endpoint'') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END
GO

use [master]
GO
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [${ad_domain_netbios}\${sql_service_account}]
GO

:Connect ${sql2_os_hostname}
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name=''AlwaysOn_health'')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name=''AlwaysOn_health'')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END
GO

:Connect ${sql1_os_hostname}
USE [master]
GO

CREATE AVAILABILITY GROUP [${aoag_name}]
WITH (AUTOMATED_BACKUP_PREFERENCE = PRIMARY,
BASIC,
DB_FAILOVER = OFF,
DTC_SUPPORT = NONE,
REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0)
FOR DATABASE [ContosoUniversity]
REPLICA ON N''${sql1_os_hostname}'' WITH (ENDPOINT_URL = N''TCP://${sql1_os_hostname}.example.com:5022'', FAILOVER_MODE = MANUAL, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SEEDING_MODE = MANUAL, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO)),
	N''${sql2_os_hostname}'' WITH (ENDPOINT_URL = N''TCP://${sql2_os_hostname}.example.com:5022'', FAILOVER_MODE = MANUAL, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, SEEDING_MODE = MANUAL, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO));

GO

:Connect ${sql2_os_hostname}
ALTER AVAILABILITY GROUP [${aoag_name}] JOIN;
GO

:Connect ${sql1_os_hostname}
BACKUP DATABASE [ContosoUniversity] TO  DISK = N''\\${witness_os_hostname}\backup\ContosoUniversity.bak'' WITH  COPY_ONLY, FORMAT, INIT, SKIP, REWIND, NOUNLOAD, COMPRESSION,  STATS = 5
GO

:Connect ${sql2_os_hostname}
RESTORE DATABASE [ContosoUniversity] FROM  DISK = N''\\${witness_os_hostname}\backup\ContosoUniversity.bak'' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5
GO

:Connect ${sql1_os_hostname}
BACKUP LOG [ContosoUniversity] TO  DISK = N''\\${witness_os_hostname}\backup\ContosoUniversity.trn'' WITH NOFORMAT, INIT, NOSKIP, REWIND, NOUNLOAD, COMPRESSION,  STATS = 5
GO

:Connect ${sql2_os_hostname}
RESTORE LOG [ContosoUniversity] FROM  DISK = N''\\${witness_os_hostname}\backup\ContosoUniversity.trn'' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5
GO

:Connect ${sql2_os_hostname}
-- Wait for the replica to start communicating
begin try
declare @conn bit
declare @count int
declare @replica_id uniqueidentifier 
declare @group_id uniqueidentifier
set @conn = 0
set @count = 30 -- wait for 5 minutes 

if (serverproperty(''IsHadrEnabled'') = 1)
	and (isnull((select member_state from master.sys.dm_hadr_cluster_members where upper(member_name COLLATE Latin1_General_CI_AS) = upper(cast(serverproperty(''ComputerNamePhysicalNetBIOS'') as nvarchar(256)) COLLATE Latin1_General_CI_AS)), 0) <> 0)
	and (isnull((select state from master.sys.database_mirroring_endpoints), 1) = 0)
begin
    select @group_id = ags.group_id from master.sys.availability_groups as ags where name = N''${aoag_name}''
	select @replica_id = replicas.replica_id from master.sys.availability_replicas as replicas where upper(replicas.replica_server_name COLLATE Latin1_General_CI_AS) = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) and group_id = @group_id
	while @conn <> 1 and @count > 0
	begin
		set @conn = isnull((select connected_state from master.sys.dm_hadr_availability_replica_states as states where states.replica_id = @replica_id), 1)
		if @conn = 1
		begin
			-- exit loop when the replica is connected, or if the query cannot find the replica status
			break
		end
		waitfor delay ''00:00:10''
		set @count = @count - 1
	end
end
end try
begin catch
	-- If the wait loop fails, do not stop execution of the alter database statement
end catch
ALTER DATABASE [ContosoUniversity] SET HADR AVAILABILITY GROUP = [${aoag_name}];
GO
GO"

sqlcmd -Q $buildag

#Add Web Service User to SQL Instances and AG Database
$addwebsvc = ":Connect ${sql1_os_hostname}
USE [master]
GO
CREATE LOGIN [${ad_domain_netbios}\${web_service_account}] FROM WINDOWS WITH DEFAULT_DATABASE=[ContosoUniversity]
GO
USE [ContosoUniversity]
GO
CREATE USER [${ad_domain_netbios}\${web_service_account}] FOR LOGIN [${ad_domain_netbios}\${web_service_account}]
GO
USE [ContosoUniversity]
GO
ALTER ROLE [db_owner] ADD MEMBER [${ad_domain_netbios}\${web_service_account}]
GO

:Connect ${sql2_os_hostname}
USE [master]
GO
CREATE LOGIN [${ad_domain_netbios}\${web_service_account}] FROM WINDOWS WITH DEFAULT_DATABASE=[ContosoUniversity]
GO"

sqlcmd -Q $addwebsvc

C:\add_dnn_listener.ps1 ${aoag_name} ${dnn_listener_name} ${dnn_listener_port}

#Update Bootstrapping Metadata
gcloud compute instances add-metadata ${sql1_os_hostname} --zone=${sql1_zone} --metadata=STATUS=READY

' | Out-File C:\stage2.ps1

'
$sql_username = "${ad_domain_netbios}\${sql_service_account}"
$sql_user_password = ConvertTo-SecureString -String (gcloud secrets versions access latest --secret=${sql_service_account_secret_id}) -AsPlainText -Force
$sql_user_credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sql_username, $sql_user_password
Set-Service -Name MSSQLSERVER -Credential $sql_user_credential
Restart-Service -Name MSSQLSERVER
' | Out-File C:\sqlsvc.ps1

'
#Script Source
#Link: https://learn.microsoft.com/en-us/azure/azure-sql/virtual-machines/windows/availability-group-distributed-network-name-dnn-listener-configure?view=azuresql

param (
   [Parameter(Mandatory=$true)][string]$Ag,
   [Parameter(Mandatory=$true)][string]$Dns,
   [Parameter(Mandatory=$true)][string]$Port
)

Write-Host "Add a DNN listener for availability group $Ag with DNS name $Dns and port $Port"

$ErrorActionPreference = "Stop"

# create the DNN resource with the port as the resource name
Add-ClusterResource -Name $Port -ResourceType "Distributed Network Name" -Group $Ag 

# set the DNS name of the DNN resource
Get-ClusterResource -Name $Port | Set-ClusterParameter -Name DnsName -Value $Dns 

# start the DNN resource
Start-ClusterResource -Name $Port

$Dep = Get-ClusterResourceDependency -Resource $Ag
if ( $Dep.DependencyExpression -match ''\s*\((.*)\)\s*'' ) {
	$DepStr = "$($Matches.1) or [$Port]"
} else {
	$DepStr = "[$Port]"
}

Write-Host "$DepStr"

# add the Dependency from availability group resource to the DNN resource
Set-ClusterResourceDependency -Resource $Ag -Dependency "$DepStr"

#bounce the AG resource
Stop-ClusterResource -Name $Ag
Start-ClusterResource -Name $Ag
' | Out-File C:\add_dnn_listener.ps1

$stage1_taskName = "SQL Server Bootstrap - Stage 1"
$s1action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "C:\stage1.ps1"
$s1trigger = New-ScheduledTaskTrigger -AtStartup

$s1principal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s1action -Trigger $s1trigger -Principal $s1principal -TaskName $stage1_taskName

$stage2skycrane_taskName = "SQL Server Bootstrap - Stage 2 Skycrane"
$s2skycraneaction = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "C:\stage2skycrane.ps1"
$s2skycranetrigger = New-ScheduledTaskTrigger -AtStartup

$s2skycraneprincipal =  New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -Action $s2skycraneaction -Trigger $s2skycranetrigger -Principal $s2skycraneprincipal -TaskName $stage2skycrane_taskName
Disable-ScheduledTask -TaskName "SQL Server Bootstrap - Stage 2 Skycrane"

#Disable Server Manager Startup
Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask