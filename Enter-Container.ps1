#Requires -PSEdition Core
#Requires -RunAsAdministrator
#Requires -Modules AWSPowerShell.NetCore

[CmdletBinding()] Param(
    $ParameterPath = "/bsv.config.psd1",
    $GpgRecipientKeyPath = "/recipient.pubkey.gpg",
    $AwsConfigPath = "/run/secrets/aws.psd1",
    $BackupSchedule = $env:BACKUP_SCHEDULE
)

# $ErrorActionPreference = "Stop"

$awsConfig = Import-PowerShellDataFile -Path $AwsConfigPath
Set-AWSCredential -AccessKey $awsConfig.AwsAccessKey -SecretKey $awsConfig.AwsSecretKey -StoreAs 'default'

$gpgKeyRegex = "^gpg\: key (?<keyid>[0-9A-F]{8})\:"
$slsMatch = gpg2 --import "$GpgRecipientKeyPath" 2>&1 |
    Select-String -Pattern $gpgKeyRegex
$recipientKeyId = $slsMatch.Matches.Groups |
    Where-Object -Property Name -EQ 'keyid' |
    Select-Object -ExpandProperty Value

"${BackupSchedule} pwsh -NoLogo -NonInteractive -NoProfile -File /usr/local/bin/Backup-SwarmVolume.ps1 -ParameterFile '$ParameterPath'" | crontab -
cron

if (-not (Test-Path -Path /var/log/bsv.log)) {
    New-Item -ItemType File -Path /var/log/bsv.log
}
Get-Content -Wait -Path /var/log/bsv.log
