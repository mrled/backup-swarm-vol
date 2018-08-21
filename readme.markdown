# `bsv-docker`: Backup Swarm Volume

A simple Docker container for backing up a Docker swarm service volume.

It takes a single swarm volume,
creates a `tar` archive of it,
optionally compresses it with `xz` (enabled by default),
encrypts it with GnuPG,
saves the SHA256 hash of the encrypted archive,
and uploads the hash and the encrypted archive to Amazon S3.

## Implementation

It's written in Powershell Core.

This is partially because I want to get more familiar with PS Core,
and partially because I'm desperately searching for a replacement for sh programming,
which I would frankly love to completely remove from my brain.

## Configuration

There are three items that must be configured when deploying bsv into a swarm.

1. A service config called `bsv.config.psd1`
2. A service config called `recipient.pubkey.gpg`
3. Service secrets called `aws.psd1`

You can also optionally configure the backup schedule.
This defaults to 2AM (in the _Docker swarm node's_ timezone) every night:

    # +-------------- minute (0 - 59)
    # | +------------ hour (0 - 23)
    # | | +---------- day of month (1 - 31)
    # | | | +-------- month (1 - 12)
    # | | | | +------ day of week (0 - 6)
    # | | | | |
    # | | | | |
    # | | | | |
      0 2 * * *

Modify this by specifying the `BACKUP_SCHEDULE` variable in crontab format.
For instance, this will back up at 4:30 AM every day instead:

    -e BACKUP_SCHEDULE:"15 4 * * *"

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
    }

### Example compose file

TODO

### Example without Swarm or compose (for testing)

This is likely not useful in the real world,
but the container can be tested by mounting Docker volumes
to the paths where Swarm service config/secret files are.

Note that service config files are in the root,
while service secrets files are in `/run/secrets`.

First, create the config files listed above in the current directory.
Then, create a test directory and put some files in it.
Finally, run a command like this:

    docker run --rm -it \
        -v ${PWD}/bsv.config.psd1:/bsv.config.psd1 \
        -v ${PWD}/recipient.pubkey.gpg:/recipient.pubkey.gpg \
        -v ${PWD}/aws.psd1:/run/secrets/aws.psd1 \
        -v ${PWD}/TestBackupDir:/srv/backuproot \
        -e BACKUP_SCHEDULE="* * * * *" \
        mrled/bsv:dev

Note that the above will run the backup every _minute_,
so you'll want to kill your test pretty quickly
to prevent sending too much test data to S3.
