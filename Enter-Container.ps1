#Requires -PSEdition Core
#Requires -RunAsAdministrator
#Requires -Modules AWSPowerShell.NetCore

[CmdletBinding()] Param(
    $ParameterPath = $env:BSV_PARAMETER_PATH,
    $GpgRecipientKeyPath = $env:GPG_RECIPIENT_KEY_PATH,
    $AwsConfigPath = $env:AWS_CONFIG_PATH,
    $BackupSchedule = $env:BACKUP_SCHEDULE
)

$awsConfig = Import-PowerShellDataFile -Path $AwsConfigPath
Set-AWSCredential -AccessKey $awsConfig.AwsAccessKey -SecretKey $awsConfig.AwsSecretKey -Region AwsRegion -StoreAs 'default'

$gpgKeyRegex = "^gpg\: key (?<keyid>[0-9A-F]{8})\:"
$slsMatch = gpg2 --import "$GpgRecipientKeyPath" 2>&1 |
    Select-String -Pattern $gpgKeyRegex
$recipientKeyId = $slsMatch.Matches.Groups |
    Where-Object -Property Name -EQ 'keyid' |
    Select-Object -ExpandProperty Value

"${BackupSchedule} pwsh -NoLogo -NonInteractive -NoProfile -File /usr/local/bin/Backup-SwarmVolume.ps1 -ParameterFile '$ParameterPath'" | crontab -e
cron

Get-Content -Tail -Path "/var/log/bsv.log"
