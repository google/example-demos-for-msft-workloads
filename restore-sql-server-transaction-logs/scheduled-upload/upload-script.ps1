Import-Module $PSScriptRoot\HelperFunctions

# Constants - fill with necessary information:
#The folder where the backup files are created. The script goes into subfolders as well.
New-Variable -Name LocalPathForBackupFiles -Value "" -Option Constant

#The bucket name where the backup files will be uploaded
New-Variable -Name BucketName -Value ""

#The full path to your google accout json key file. It is used by the script to authenticate against the bucket.
New-Variable -Name GoogleAccountKeyFile -Value "" -Option Constant

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

UploadToCloudBucket $LocalPathForBackupFiles $GoogleAccountKeyFile $BucketName $DateTimeFormat $LogFile