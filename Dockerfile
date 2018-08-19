FROM microsoft/powershell:6.0.4-ubuntu-16.04
LABEL maintainer "me@micahrl.com"

# The path to the Backup-SwarmVolume configuration file
# Add this file in as a Docker swarm service config
ENV BSV_PARAMETER_PATH /bsv.config.psd1

# The path to a public GPG key which will be used to encrypt the backups before uploading
# Add this file in as a Docker swarm service config
ENV GPG_RECIPIENT_KEY_PATH /recipient.pubkey.gpg

# The path to a PowerShell Data File containing an AWS secret, key, and region
# Add this in as a Docker swarm service secret
ENV AWS_CONFIG_PATH /run/secrets/aws.psd1

# The cron schedule for running the backup script
# min hour day month weekday
ENV BACKUP_SCHEDULE "0 2 * * *"

RUN true \
    && apt-get update \
    && apt-get install -y \
        gnupg2 \
        xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    \
    # I think dumb-init is in 18.04, but the latest Powershell container is based on 16.04 at this time which doesn't have it
    && wget https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64.deb \
    && dpkg -i dumb-init_1.2.2_amd64.deb \
    && rm dumb-init_1.2.2_amd64.deb \
    \
    && Install-Module -Scope AllUsers -Name AWSPowerShell.NetCore -Force \
    && true

VOLUME /srv/backuproot

COPY ["Enter-Container.ps1", "Backup-SwarmVolume.ps1", "/usr/local/bin/"]

ENTRYPOINT ["/usr/bin/dumb-init", "--", "pwsh", "-NoLogo", "-NonInteractive", "-NoProfile", "-File", "/usr/local/bin/Backup-SwarmVolume.ps1"]

