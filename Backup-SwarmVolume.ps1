#Requires -PSEdition Core
#Requires -RunAsAdministrator
#Requires -Modules AWSPowerShell.NetCore

[CmdletBinding(DefaultParameterSetName='CmdLine')] Param(
    [Parameter(ParameterSetName='ParamFile', Mandatory)] $ParameterFile,
    [Parameter(ParameterSetName='CmdLine', Mandatory)] $BackupPath,
    [Parameter(ParameterSetName='CmdLine', Mandatory)] $BackupBaseName,
    [Parameter(ParameterSetName='CmdLine', Mandatory)] $GpgRecipientId,
    [Parameter(ParameterSetName='CmdLine', Mandatory)] $S3BucketName,
    [Parameter(ParameterSetName='CmdLine')] $LogPath = "/var/log/bsv.log",
    [Parameter(ParameterSetName='CmdLine')] [switch] $NoCompress
)

$ErrorActionPreference = "Stop"

function Write-Log {
    [CmdletBinding()] Param(
        [Parameter(Mandatory)] $Message,
        [switch] $Throw
    )
    $msg = "$(Get-Date -UFormat '%Y-%m-%d-%H-%M-%S') [$PSCommandPath] $Message"
    if ($Throw) {
        throw $msg
    } else {
        Write-Output -InputObject $msg
    }
}

function New-TemporaryDirectory {
    [CmdletBinding()] Param()
    $file = New-TemporaryFile
    Remove-Item -Path $file.FullName
    New-item -ItemType Directory $file.FullName
}

switch ($PsCmdlet.ParameterSetName) {
    'ParamFile' {
        $params = Import-PowerShellDataFile -Path $ParameterFile
        . $PSCommandPath @params
    }
    'CmdLine' {}
    default {
        throw "Do not understand parameter set $($PsCmdlet.ParameterSetName)"
    }
}

try {
    $startTime = Get-Date -UFormat '%Y-%m-%d-%H-%M-%S'

    $BackupPath = Resolve-Path -Path $BackupPath | Select-Object -ExpandProperty Path

    if ($Compress) {
        $fileExt = ".tar.zx.gpg"
        $tarArgs = "-cvJ"
    } else {
        $fileExt = ".tar.gpg"
        $tarArgs = "-cv"
    }
    $archiveName = "${BackupBaseName}.${startTime}.${fileExt}"

    $workDir = New-TemporaryDirectory
    $archivePath = Join-Path -Path $workDir -ChildPath $archiveName
    $hashPath = Join-Path -Path $workDir -ChildPath "${archiveName}.sha256"

    tar $tarArgs $BackupPath |
        gpg2 --encrypt --recipient "$GpgRecipientId" --output "$archivePath" --trust-model always
    if ($LASTEXITCODE -NE 0) {
        Write-Log -Throw -Message "Failed to create encrypted tar archive; pipeline exited with $LASTEXITCODE"
    }
    Write-Log -Message "Saved archive to $archivePath, encrypted for $GpgRecipientId"

    $hash = Get-FileHash -Algorithm SHA256
    Out-File -InputObject "$($hash.Hash) $archiveName" -FilePath $hashPath
    Write-Log -Message "Saved sha256 hash of $($hash.Hash) to $hashPath"

    Write-S3Object -BucketName $S3BucketName -File $hashPath
    Write-Log -Message "Uploaded $hashPath to bucket $S3BucketName"

    Write-S3Object -BucketName $S3BucketName -File $archivePath
    Write-Log -Message "Uploaded $archivePath to bucket $S3BucketName"

    Remove-Item -Recurse -Force $workDir
    Write-Log -Messgea "Removed working directory $workDir"

    Write-Log -Message "Backup complete"

} catch {
    Write-Log -Message "Backup failed with error: $_"
    throw $_
}