#!/bin/sh

echo "$RECIPIENTKEY_B64" | base64 -d 

echo "${BACKUPSCHEDULE} /usr/local/bin/bsv.sh" | crontab -

exec crond -f
