# Default variables
$uploadedObjectsNumber=0
$currentDateTimeUtc = (Get-Date).ToUniversalTime()

# Define the logic to set the content metadata the functions below. Exposed in functions for visibility and convenience.
function Get-CloudSqlInstance-MetadataTag {
  param ($file, $CloudSqlInstance)
  
  If ($CloudSqlInstance.Length -gt 0) {
    return $CloudSqlInstance
  }

  return $file.Name.Split("_")[0]

}

function Get-DatabaseName-MetadataTag {
  param ($file)
  return $file.Directory.Name
}

function Get-BackupType-MetadataTag {
  param ($file)

  If ($file.Name -like "*full*") {return "FULL"}  
  If ($file.Name -like "*diff*") {return "DIFF"}  
  return "TLOG"
}

function Get-Recovery-MetadataTag {
  param ($file)
  # Change to True in case of restore with recovery
  return "False"
}

# Constants - fill with necessary information:

#The folder where the backup files are created. The script goes into subfolders as well.
New-Variable -Name LocalPathForBackupFiles -Value "" -Option Constant

#The bucket name where the backup files will be uploaded
New-Variable -Name BucketName -Value "" -Option Constant

#The full path to your google accout json key file. It is used by the script to authenticate against the bucket.
New-Variable -Name GoogleAccountKeyFile -Value "" -Option Constant

#The name of the Cloud SQL for SQL Server instance name. If provided, it will be used for metadata
New-Variable -Name CloudSqlInstanceName -Value "" -Option Constant

New-Variable -Name LogFile -Value "log.json" -Option Constant
New-Variable -Name DateTimeFormat -Value "yyyy-MM-dd HH:mm:ss.fff" -Option Constant


# Validations
If (-Not (Test-Path $LocalPathForBackupFiles)) {
  throw "The provided value for LocalPathForBackupFiles $LocalPathForBackupFiles is not a valid path."
}

If (-Not ($BucketName)) {
  throw "The value of the BucketName variable must not be empty."
}

If (-Not (Test-Path $GoogleAccountKeyFile -PathType Leaf)) {
  throw "The file for GoogleAccountKeyFile $GoogleAccountKeyFile does not exist."
}

If (Test-Path -Path $LogFile -PathType Leaf)  {  
  $log = Get-Content $LogFile -Raw | ConvertFrom-Json
}
else {  
  $log = New-Object -TypeName psobject
  $log | Add-Member -MemberType NoteProperty -Name LastRunMaxWriteDateTimeUtc -Value ''
  $log | Add-Member -MemberType NoteProperty -Name LastRunTimeUtc -Value ''
  $log | Add-Member -MemberType NoteProperty -Name LastRunUploadedObjectsNumber -Value 0
}

$lastMaxDateTimeUtcString = if ($log.LastRunMaxWriteDateTimeUtc) {$log.LastRunMaxWriteDateTimeUtc} else {[DateTime]::MinValue.ToString($DateTimeFormat)}
$lastMaxDateTimeUtc=[datetime]::ParseExact($lastMaxDateTimeUtcString,$DateTimeFormat,$null)
$newMaxDateTimeUtc = $lastMaxDateTimeUtc

# filter out existing files with an older timestamp than the reference data of the last run
$recentlyAddedFiles = Get-ChildItem -Path $LocalPathForBackupFiles -Attributes !Directory *.* -Recurse | 
  Where-Object {[datetime]::ParseExact($_.LastWriteTimeUtc.ToString($DateTimeFormat),$DateTimeFormat,$null) -gt $lastMaxDateTimeUtc}

if ($recentlyAddedFiles.Count -gt 0) {
  
  gcloud auth activate-service-account --key-file $GoogleAccountKeyFile --quiet
  
  Foreach ($file in $recentlyAddedFiles)
  {
      try
      {        
        $CloudSqlInstance = Get-CloudSqlInstance-MetadataTag $file, $CloudSqlInstanceName
        $DatabaseName = Get-DatabaseName-MetadataTag $file
        $BackupType = Get-BackupType-MetadataTag $file
        $Recovery = Get-Recovery-MetadataTag $file

        $metadata = @{CloudSqlInstance = $CloudSqlInstance; DatabaseName = $DatabaseName; BackupType=$BackupType ; Recovery=$Recovery}
        
        $uploadDestination = $file.Name
        New-GcsObject -Bucket $BucketName -ObjectName $uploadDestination -Metadata $metadata -File $file.FullName -Force
        
        $uploadedObjectsNumber++;
        $newMaxDateTimeUtc = if ($file.LastWriteTimeUtc -gt $newMaxDateTimeUtc) {$file.LastWriteTimeUtc} else {$newMaxDateTimeUtc}

        # persist reference data for next run
        $log.LastRunMaxWriteDateTimeUtc = $newMaxDateTimeUtc.ToString($DateTimeFormat)
        $log.LastRunUploadedObjectsNumber = $uploadedObjectsNumber
        $log.LastRunTimeUtc = $currentDateTimeUtc.ToString($DateTimeFormat)
        $log | ConvertTo-Json -Depth 1 | Out-File $LogFile        
      }
      catch
      {    
        throw $_.Exception.GetType().FullName,$_.Exception.Message
        exit 1
      }
  }

}
