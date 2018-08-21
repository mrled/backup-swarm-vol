FROM microsoft/powershell:6.0.4-ubuntu-16.04
LABEL maintainer "me@micahrl.com"

# The cron schedule for running the backup script
# min hour day month weekday
ENV BACKUP_SCHEDULE "0 2 * * *"

RUN true \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y \
        cron \
        gnupg2 \
        xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && true

RUN true \
    && pwsh -Command "Install-Module -Scope AllUsers -Name AWSPowerShell.NetCore -Force" \
    && true

# I think dumb-init is in 18.04, but the latest Powershell container is based on 16.04 at this time which doesn't have it
RUN true \
    && export DIVER="1.2.2" \
    && export DIDEB="dumb-init_${DIVER}_amd64.deb" \
    && curl -s -L -o "/root/${DIDEB}" "https://github.com/Yelp/dumb-init/releases/download/v${DIVER}/${DIDEB}" \
    && dpkg -i "/root/${DIDEB}" \
    && rm "/root/${DIDEB}" \
    && true

VOLUME /srv/backuproot

COPY ["Enter-Container.ps1", "Backup-SwarmVolume.ps1", "/usr/local/bin/"]

ENTRYPOINT ["/usr/bin/dumb-init", "--", "pwsh", "-NoLogo", "-NonInteractive", "-NoProfile", "-File", "/usr/local/bin/Enter-Container.ps1"]
