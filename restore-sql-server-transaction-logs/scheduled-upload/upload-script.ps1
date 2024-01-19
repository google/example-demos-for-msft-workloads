[ValidateScript({if (-Not (Test-Path $_)) {throw "The provided value for LocalPathForBackupFiles ${_} is not a valid path."} })][string]$LocalPathForBackupFiles=""
[ValidateScript({if (-Not ($_)) {throw "The value of the BucketName variable must not be empty."} })][string]$BucketName=""
[ValidateScript({if (-Not (Test-Path $_ -PathType Leaf)) {throw "The file for GoogleAccountKeyFile ${_} does not exist."} })][IO.FileInfo]$GoogleAccountKeyFile=""

$uploadedObjectsNumber=0
$logFile="log.json"
$DateTimeFormat="yyyy-MM-dd HH:mm:ss.fff"
$currentDateTimeUtc = (Get-Date).ToUniversalTime()

If (Test-Path -Path $logFile -PathType Leaf)  {  
  $log = Get-Content $logFile -Raw | ConvertFrom-Json
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
$recentlyAddedFiles = Get-ChildItem -Path $LocalPathForBackupFiles *.* -Recurse | 
  Where-Object {[datetime]::ParseExact($_.LastWriteTimeUtc.ToString($DateTimeFormat),$DateTimeFormat,$null) -gt $lastMaxDateTimeUtc}


if ($recentlyAddedFiles.Count -gt 0) {

  $googleServiceAccount = Get-ChildItem -Path $GoogleAccountKeyFile
  gcloud auth activate-service-account --key-file $googleServiceAccount --quiet

  Foreach ($file in $recentlyAddedFiles)
  {
      try
      {      
        $uploadDestination = $BucketUploadFolder+"/"+$file.Name
        New-GcsObject -Bucket $BucketName -ObjectName $uploadDestination -File $file.FullName -Force      
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
$log.LastRunMaxWriteDateTimeUtc = $newMaxDateTimeUtc.ToString($DateTimeFormat)
$log.LastRunUploadedObjectsNumber = $uploadedObjectsNumber
$log.LastRunTimeUtc = $currentDateTimeUtc.ToString($DateTimeFormat)
$log | ConvertTo-Json -Depth 1 | Out-File $logFile
