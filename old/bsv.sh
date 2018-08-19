#!/bin/sh

set -e

# Variables for convenience later
BACKUPDIR="/srv/backuproot"
DATEFMT="+%Y-%m-%d-%H-%M-%S"
NOW=$(date "$DATEFMT")

# Environment variables with default values
if test -z "$COMPRESS" || test "$COMPRESS" != 1; then
    COMPRESS=0
fi
ADDITIONAL_ENVFILE="${ADDITIONAL_ENVFILE:-""}"

set -u

log() {
    echo "$(date "$DATEFMT") [$0] $*"
}

# If you haven't set these environment variables ahead of time,
# this script will fail
log "Backup directory:         ${BACKUPDIR}"
log "Basename:                 ${BASENAME}"
log "Recipient:                ${RECIPIENT}"
log "Compress:                 ${COMPRESS}"
log "Additional env file:      ${ADDITIONAL_ENVFILE}"
log "S3 bucket:                ${S3BUCKET}"

if ! test -e "$BACKUPDIR"; then
    echo "No such file: ${BACKUPDIR}"
    exit 1
elif gpg --list-keys | grep -q "$RECIPIENT"; then
    echo "No such recipient in GPG trust database: ${RECIPIENT}"
    exit 1
fi
case "$S3BUCKET" in
    "S3://*") ;;
    *) echo "S3 bucket name must start with s3://"; exit 1;;
esac

FILEXT=".tar.gpg"
TARARGS="-cv"
if test "$COMPRESS" = 1; then
    FILEXT=".tar.xz.gpg"
    TARARGS="${TARARGS}J"
fi
ARCHIVENAME=${BASENAME}.${NOW}.${FILEXT}

tar "$TARARGS" "$BACKUPDIR" |
    gpg --encrypt --recipient "$RECIPIENT" --output "/tmp/${ARCHIVENAME}" --trust-model always
log "Saved encrypted archive to /tmp/${ARCHIVENAME}"

cd /tmp
SHASUM=$(sha256sum "$ARCHIVENAME")
echo "$SHASUM" > "${ARCHIVENAME}.sha256"
log "Saved has to /tmp/${ARCHIVENAME}.sha256: '${SHASUM}'"

aws s3 cp "/tmp/${ARCHIVENAME}.sha256" "${S3BUCKET}/${ARCHIVENAME}.sha256"
log "Uploaded ${S3BUCKET}/${ARCHIVENAME}.sha256"

aws s3 cp "/tmp/${ARCHIVENAME}" "${S3BUCKET}/${ARCHIVENAME}"
log "Uploaded ${S3BUCKET}/${ARCHIVENAME}"

rm "/tmp/${ARCHIVENAME}"
log "Removed temporary encrypted archive /tmp/${ARCHIVENAME}"

log "Done with backup started at ${NOW}"
