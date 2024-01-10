$settingsFile="<full-path-to-your-script>\settings.json"
$uploadedObjectsNumber=0
$currentDateTimeUtc = (Get-Date).ToUniversalTime()

# read from json settings file
$settings = Get-Content $settingsFile -Raw | ConvertFrom-Json


# read the MaxWriteDateTime of the last run
$lastMaxDateTimeUtcString = if ($settings.LastRunMaxWriteDateTimeUtc) {$settings.LastRunMaxWriteDateTimeUtc} else {[DateTime]::MinValue.ToString($settings.DateTimeFormat)}
$lastMaxDateTimeUtc=[datetime]::ParseExact($lastMaxDateTimeUtcString,$settings.DateTimeFormat,$null)
$newMaxDateTimeUtc = $lastMaxDateTimeUtc

# get all the files older than the last run's MaxWriteDateTime
$recentlyAddedFiles = Get-ChildItem -Path $settings.LocalPathForBackupFiles *.* -Recurse | 
  Where-Object {[datetime]::ParseExact($_.LastWriteTimeUtc.ToString($settings.DateTimeFormat),$settings.DateTimeFormat,$null) -gt $lastMaxDateTimeUtc}

# upload the matching files to the GCS bucket
if ($recentlyAddedFiles.Count -gt 0) {

  $googleServiceAccount = Get-ChildItem -Path $settings.GoogleAccountKeyFile
  gcloud auth activate-service-account --key-file $googleServiceAccount --quiet

  Foreach ($file in $recentlyAddedFiles)
  {
      try
      {      
        $uploadDestination = $settings.BucketUploadFolder+"/"+$file.Name
        New-GcsObject -Bucket $settings.BucketName -ObjectName $uploadDestination -File $file.FullName -Force      
        $uploadedObjectsNumber++;
        $newMaxDateTimeUtc = if ($file.LastWriteTimeUtc -gt $newMaxDateTimeUtc) {$file.LastWriteTimeUtc} else {$newMaxDateTimeUtc}        
      }    
      catch
      {    
        throw $_.Exception.GetType().FullName,$_.Exception.Message
        exit 1
      }
  }

}

# persist reference data for next run
$settings.LastRunMaxWriteDateTimeUtc = $newMaxDateTimeUtc.ToString($settings.DateTimeFormat)
$settings.LastRunUploadedObjectsNumber = $uploadedObjectsNumber
$settings.LastRunTimeUtc = $currentDateTimeUtc.ToString($settings.DateTimeFormat)
$settings | ConvertTo-Json -Depth 1 | Out-File $settingsFile
