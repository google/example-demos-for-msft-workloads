# Define the logic to set the content metadata the functions below. Exposed in functions for visibility and convenience.
function Get-CloudSqlInstanceMetadataTag {
    param ($file)
  
    #Fill in with the destination Cloud SQL for SQL Server instance name
    return ""
  }
  
  function Get-DatabaseNameMetadataTag {
    param ($file)  
    return $file.Directory.Name
  }
  
  function Get-BackupTypeMetadataTag {
    param ($file)
  
    If ($file.Name -like "*full*") {return "FULL"}  
    If ($file.Name -like "*diff*") {return "DIFF"}  
    return "TLOG"
  }
  
  function Get-RecoveryMetadataTag {
    param ($file)
    # Change to True in case of restore with recovery
    return "False"
  }
  
  function Get-LogObject {
    param ($LogFile)
    
    If (Test-Path -Path $LogFile -PathType Leaf)  {  
      $log = Get-Content $LogFile -Raw | ConvertFrom-Json
    }
    else {  
      $log = New-Object -TypeName psobject
      $log | Add-Member -MemberType NoteProperty -Name LastRunMaxWriteDateTimeUtc -Value ''
      $log | Add-Member -MemberType NoteProperty -Name LastRunTimeUtc -Value ''
      $log | Add-Member -MemberType NoteProperty -Name LastRunUploadedObjectsNumber -Value 0
    }
    return $log
  }
  
  function Get-LastMaxDateTimeUtc {
    param ($log, $DateTimeFormat)
    
    $lastMaxDateTimeUtcString = if ($log.LastRunMaxWriteDateTimeUtc) {$log.LastRunMaxWriteDateTimeUtc} else {[DateTime]::MinValue.ToString($DateTimeFormat)}
    $lastMaxDateTimeUtc=[datetime]::ParseExact($lastMaxDateTimeUtcString,$DateTimeFormat,$null)  
    return $lastMaxDateTimeUtc
  }
  
  function Set-LogData {
    param ($newMaxDateTimeUtc, $uploadedObjectsNumber, $currentDateTimeUtc, $DateTimeFormat, $LogFile)
    
    $logset = New-Object -TypeName psobject
    $logset | Add-Member -MemberType NoteProperty -Name LastRunMaxWriteDateTimeUtc -Value ''
    $logset | Add-Member -MemberType NoteProperty -Name LastRunTimeUtc -Value ''
    $logset | Add-Member -MemberType NoteProperty -Name LastRunUploadedObjectsNumber -Value 0
  
    $logset.LastRunMaxWriteDateTimeUtc = $newMaxDateTimeUtc.ToString($DateTimeFormat)
    $logset.LastRunUploadedObjectsNumber = $uploadedObjectsNumber
    $logset.LastRunTimeUtc = $currentDateTimeUtc.ToString($DateTimeFormat)
    $logset | ConvertTo-Json -Depth 1 | Out-File $LogFile     
    
    return $logset
  }
  
  function Get-Auth {
    param ($AccountKeyFile)
    gcloud auth activate-service-account --key-file $AccountKeyFile --quiet
    return
  }
  
  function UploadNewGCSObject {
    param ($BucketName, $uploadDestination, $metadata, $fileName)
    New-GcsObject -Bucket $BucketName -ObjectName $uploadDestination -Metadata $metadata -File $fileName -Force
    return
  }
  
  function UploadToCloudBucket {
    param ($LocalPathForBackupFiles, $GoogleAccountKeyFile, $BucketName, $DateTimeFormat, $LogFile)
    
    $uploadedObjectsNumber=0
    $currentDateTimeUtc = (Get-Date).ToUniversalTime()
  
    $log = Get-LogObject $LogFile
    $lastMaxDateTimeUtc = Get-LastMaxDateTimeUtc $log $DateTimeFormat
    $newMaxDateTimeUtc = $lastMaxDateTimeUtc
    
    # filter out existing files with an older timestamp than the reference data of the last run
    $recentlyAddedFiles = Get-ChildItem -Path $LocalPathForBackupFiles -Attributes !Directory *.* -Recurse | 
      Where-Object {[datetime]::ParseExact($_.LastWriteTimeUtc.ToString($DateTimeFormat),$DateTimeFormat,$null) -gt $lastMaxDateTimeUtc}
    
    if ($recentlyAddedFiles.Count -gt 0) {
      
      Get-Auth $GoogleAccountKeyFile
      
      Foreach ($file in $recentlyAddedFiles)
      {
          try
          {        
            $CloudSqlInstance = Get-CloudSqlInstanceMetadataTag $file
            $DatabaseName = Get-DatabaseNameMetadataTag $file
            $BackupType = Get-BackupTypeMetadataTag $file
            $Recovery = Get-RecoveryMetadataTag $file
    
            $metadata = @{CloudSqlInstance = $CloudSqlInstance; DatabaseName = $DatabaseName; BackupType=$BackupType ; Recovery=$Recovery}
            
            $uploadDestination = $file.Name
            
            UploadNewGCSObject $BucketName $uploadDestination $metadata $file.FullName
  
            $uploadedObjectsNumber++;
            $newMaxDateTimeUtc = if ($file.LastWriteTimeUtc -gt $newMaxDateTimeUtc) {$file.LastWriteTimeUtc} else {$newMaxDateTimeUtc}
    
            # persist reference data for next run
            Set-LogData $newMaxDateTimeUtc $uploadedObjectsNumber $currentDateTimeUtc $DateTimeFormat $LogFile
       
          }
          catch
          {    
            throw $_.Exception.GetType().FullName,$_.Exception.Message
            exit 1
          }
      }
    
    }    
  
    return
  }
  
  
  
  