#!/bin/sh

set -e

# Default values
true ${RSYNC_SRC:=/rsync_src}
true ${RSYNC_DST:=/rsync_dst}

/usr/bin/envsubst < "/etc/ssmtp/ssmtp.conf.tmpl" > "/etc/ssmtp/ssmtp.conf"

# Make sure that the group and users specified by the user exist
if ! getent group "${RSYNC_GID}" &>/dev/null; then
    addgroup -g "${RSYNC_GID}" "rsynccron"
fi
RSYNC_GROUP="$(getent group "${RSYNC_GID}" | cut -d: -f1)"

if ! getent passwd "${RSYNC_UID}" &>/dev/null; then
    adduser -u "${RSYNC_UID}" -H "rsynccron" "${RSYNC_GROUP}"
fi
RSYNC_USER="$(getent passwd "${RSYNC_UID}" | cut -d: -f1)"

if ! getent group "${RSYNC_GROUP}" | grep "${RSYNC_USER}" &>/dev/null; then
    addgroup "${RSYNC_USER}" "${RSYNC_GROUP}"
fi

# Create a rsync script, makes it easier to sudo
cat << EOF > /run-rsync.sh
echo "-----------------Rsync started at \$(date)"
rm /rsync.log
sudo -u "${RSYNC_USER}" -g "${RSYNC_GROUP}" \
    rsync \
        ${RSYNC_OPTIONS} \
        ${RSYNC_SRC}/ \
        ${RSYNC_DST} --log-file=/rsync.log

#Email Notification
if [[ \$? -eq 0 ]]; then
echo "Rsync successful at \$(date)"
else
echo "Rsync error at \$(date). Sending notification..."

if [[ ! -z ${APPRISE_NOTIFICATION_URLS} ]];then
    cat /rsync.log | apprise $APPRISE_NOTIFICATION_URLS
else
    cat /rsync.log | mail -s "Rsync error detected on host: ${HOSTNAME}" "${MAIL_TO}"
fi

echo "Notification sent"
fi

EOF
chmod +x /run-rsync.sh

if [[ ! -z ${APPRISE_NOTIFICATION_URLS} ]];then
    df -h | grep rsync | apprise $APPRISE_NOTIFICATION_URLS
else
    df -h | grep rsync | mail -s "Rsync error (EmailTest) detected on host: ${HOSTNAME}" "${MAIL_TO}"
fi

# Setup our crontab entry
export CRONTAB_ENTRY="${RSYNC_CRONTAB} sh /run-rsync.sh"
