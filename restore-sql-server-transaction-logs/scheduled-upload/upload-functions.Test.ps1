# Import the Pester module
using module Pester

# Import the module containing your functions
Import-Module $PSScriptRoot\HelperFunctions

# Set the path for test files
$TestFilesPath = Join-Path -Path $PSScriptRoot -ChildPath "TestFiles"

# Create a test directory if it doesn't exist
if (-not (Test-Path -Path $TestFilesPath -PathType Container)) {
    New-Item -ItemType Directory -Path $TestFilesPath | Out-Null
}

# Helper function to create test files
function Create-TestFile {
    param (
        $fileName,
        $content = ""
    )

    $filePath = Join-Path -Path $TestFilesPath -ChildPath $fileName
    $content | Out-File -FilePath $filePath -Force
}

# BeforeEach block to create test files
BeforeAll {
    # Create test files
    Create-TestFile -fileName "FullBackupFile.bak"
    Create-TestFile -fileName "DiffBackupFile.bak"
    Create-TestFile -fileName "BackupFile.bak"
    Create-TestFile -fileName "OtherFile.txt"
}


# Describe block for Get-DatabaseNameMetadataTag function
Describe "Get-DatabaseNameMetadataTag" {
    It "Returns the directory name" {
        $file = Get-Item -Path "$TestFilesPath\FullBackupFile.bak"
        $result = Get-DatabaseNameMetadataTag -file $file
        $result | Should -Be $file.Directory.Name
    }
}

# Describe block for Get-BackupTypeMetadataTag function
Describe "Get-BackupTypeMetadataTag" {
    It "Returns 'FULL' for a full backup file" {
        $file = Get-Item -Path "$TestFilesPath\FullBackupFile.bak"
        $result = Get-BackupTypeMetadataTag -file $file
        $result | Should -Be "FULL"
    }


    It "Returns 'DIFF' for a differential backup file" {
        $file = Get-Item -Path "$TestFilesPath\DiffBackupFile.bak"
        $result = Get-BackupTypeMetadataTag -file $file
        $result | Should -Be "DIFF"
    }

    It "Returns 'TLOG' for a transaction log backup file" {
        $file = Get-Item -Path "$TestFilesPath\BackupFile.bak"
        $result = Get-BackupTypeMetadataTag -file $file
        $result | Should -Be "TLOG"
    }
}

# Describe block for Get-LogObject function
Describe "Get-LogObject" {
    It "Returns a valid log object" {
        $LogFile = "LogFile.json"
        $result = Get-LogObject -LogFile $LogFile
        $result | Should -Not -BeNullOrEmpty
    }
}

# Describe block for Set-LogData function
Describe "Set-LogData" {
    It "Creates a log object with correct properties" {
        $newMaxDateTimeUtc = Get-Date
        $uploadedObjectsNumber = 10
        $currentDateTimeUtc = Get-Date
        $DateTimeFormat = "yyyy-MM-dd HH:mm:ss"
        $LogFile = "TestLogFile.json"
        Set-LogData -newMaxDateTimeUtc $newMaxDateTimeUtc -uploadedObjectsNumber $uploadedObjectsNumber -currentDateTimeUtc $currentDateTimeUtc -DateTimeFormat $DateTimeFormat -LogFile $LogFile
        $log = Get-Content $LogFile | ConvertFrom-Json
        $log.LastRunMaxWriteDateTimeUtc | Should -Be $newMaxDateTimeUtc.ToString($DateTimeFormat)
        $log.LastRunUploadedObjectsNumber | Should -Be $uploadedObjectsNumber
        $log.LastRunTimeUtc | Should -Be $currentDateTimeUtc.ToString($DateTimeFormat)
    }
}

# Describe block for UploadToCloudBucket function
Describe "UploadToCloudBucket" {
    # You may need to mock some commands or use Pester's -MockWith parameter to test specific behaviors
    It "Does not throw an exception for valid inputs" {
        
        # Mock the upload and auth commands
        Mock -CommandName 'Get-Auth' -MockWith { return } -ModuleName HelperFunctions
        Mock -CommandName 'UploadNewGCSObject' -MockWith {return } -ModuleName HelperFunctions
        Mock -CommandName 'Set-LogData' -MockWith { return } -ModuleName HelperFunctions

        $LocalPathForBackupFiles = $TestFilesPath
        $GoogleAccountKeyFile = "NotExistingKeyFile.json"
        $BucketName = ""
        $DateTimeFormat = "yyyy-MM-dd HH:mm:ss"
        $LogFile = "NotExistingLogFile.json"
        { UploadToCloudBucket -LocalPathForBackupFiles $LocalPathForBackupFiles -GoogleAccountKeyFile $GoogleAccountKeyFile -BucketName $BucketName -DateTimeFormat $DateTimeFormat -LogFile $LogFile } | Should -Not -Throw
    }
}

# AfterAll block to clean up test files
AfterAll {
    # Remove test files
    if (Test-Path $TestFilesPath) {Remove-Item -Path $TestFilesPath -Recurse -Force}
    if (Test-Path "TestLogFile.json") {Remove-Item -Path "TestLogFile.json"}
}