# Backup Swarm Volume

A simple Docker container for backing up a Docker swarm service volume.

It takes a single swarm volume,
creates a `tar` archive of it,
optionally compresses it with `xz` (enabled by default),
encrypts it with GnuPG,
saves the SHA256 hash of the encrypted archive,
and uploads the hash and the encrypted archive to Amazon S3.

## Implementation

It's written in Powershell Core.

Everyone should use Powershell :) no more sh/bash scripts please and thank you.

## Configuration

There are three items that must be configured when deploying bsv into a swarm.

1. A service config called bsv.config.psd1
2. A service config called recipient.pubkey.gpg
3. Service secrets called aws.psd1

### Service config: `bsv.config.psd1`

This is a PowerShell Data File that contains parameters for the `Backup-SwarmVolume.ps1` script.
It might look like this:

    @{
        # The source path for the backup.
        # This should be the same as the VOLUME in Dockerfile.
        BackupPath = "/srv/backuproot"

        # The base name for the backup.
        # Backups will be named "${BackupBaseName}.${TimeStamp}.${FileExtention}" in S3.
        BackupBaseName = "SomeVolumeBackup"

        # The recipient ID for the GPG key to encrypt with.
        # The GPG key itself must be added as a separate Docker config.
        # This ID can be either the email address or key ID.
        GpgRecipientId = "recipient@example.com"

        # The S3 bucket name to save backups to.
        S3BucketName = "example-s3-bucket"

        # Do not compress backups with xz before encrypting.
        NoCompress = $False
    }

### Service config: `recipient.pubkey.gpg`

This is a GnuPG public key,
which will be used to encrypt the archive before it is uploaded to S3.
It can be in ASCII-armored or binary format.

Note that the `GpgRecipientId` field in `bsv.config.psd1` must be the ID for this key.

### Service secrets: `aws.psd1`

This is a PowerShell Data File that contains an AWS key, secret, and region.

Note that unlike the previous two items,
this must be service secrets, not a service config.

It might look like this:

    @{
        AwsAccessKey = "AKIAIOSFODNN7EXAMPLE"
        AwsSecretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        AwsRegion = "us-east-1"
    }
