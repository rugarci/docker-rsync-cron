Forked to be used on Rasberry Pi and send email in case of rsync process error

# docker-rsync-cron

This is a cronjob docker container which is used to regularly sync two
docker volumes using rsync.

This image is based off of
[dkruger/cron](https://hub.docker.com/r/dkruger/cron/) which provides a simple
cron implementation. The cron daemon is used to execute `rsync` which will
copy the contents of the `rsync_src` volume to the `rsync_dst` volume. The
specific options are configurable via environment variables.

Checkout the [example docker-compose.yml](example/docker-compose.yml) for an
example of setting up the container with named NFS volumes using `Netshare`.

## Using the image

The image is configurable via environment variables for configuring the rsync
command settings:

* `RSYNC_CRONTAB`: The crontab time entry, defaults to nightly at midnight
* `RSYNC_OPTIONS`: Flags passed to `rsync`, defaults to
`--archive --timeout=3600`
* `RSYNC_UID`: The UID to use when calling rsync, defaults to 0
* `RSYNC_GID`: The GID to use when calling rsync, defaults to 0
* `RSYNC_SRC`: Source folder or url, defaults to /rsync_src
* `RSYNC_DST`: Destination folder or url, defaults to /rsync_dst

Additional environment variables for Apprise notifications (https://github.com/caronc/apprise):
* `APPRISE_NOTIFICATION_URLS`: mailto://userid:pass@domain.com,tgram://bottoken/ChatID

Additional environment variables for sending mails (if previous var is not defined):

* `MAIL_TO`: yyyyyyy@gmail.com
* `SMTP_ROOT`: xxxxxx@gmail.com
* `SMTP_HOSTNAME` : rsync-cron
* `SMTP_MAIL_HUB`: smtp.gmail.com:587
* `SMTP_AUTH_USER`: xxxxxxx@gmail.com 
* `SMTP_AUTH_PASS`: xxxxxxxx 

The image defines two volumes: `/rsync_src`, and `/rsync_dst`. The contents of
`/rsync_src` will be copied to `/rsync_dst` on the interval defined by the
crontab entry.

The `rsync` command is called using the format `rsync /rsync_src/ /rsync_dst`,
so that the *contents* of `/rsync_src` will be copied no the directory itself.

Here is an example command for executing the container two rsync two NFS mounts
using the `Netshare` volume plugin:
```bash
docker run \
    --name my-nfs-sync \
    --volume-driver=nfs \
    -v master-svr/volume1/master:/rsync_src \
    -v local-svr/export:/rsync_dst \
    -e RSYNC_OPTIONS="--archive --timeout=3600 --delete"  -e MAIL_TO=yyyyyyy@gmail.com -e SMTP_ROOT=xxxxxx@gmail.com -e SMTP_HOSTNAME=rsync-cron -e SMTP_MAIL_HUB=smtp.gmail.com:587 -e SMTP_AUTH_USER=xxxxxxx@gmail.com -e SMTP_AUTH_PASS=xxxxxxxx 
    rugarci/rsync-cron:latest
```

For Docker compose

```yaml
  rsync-cron:
    image: rugarci/rsync-cron
    environment:
      - RSYNC_CRONTAB=35 2 * * *
      - RSYNC_UID=0
      - RSYNC_GID=0
      - RSYNC_OPTIONS=--archive --timeout=3600 --delete --stats -h
      - APPRISE_CONNECTION_URLS=mailto://192.168.8.128:1025?user=userid
```

You can also rsync a remote host with

```
  rsync-remote:
    image: rugarci/rsync-cron
    environment:
      - RSYNC_SRC=rsync://remote_host/mirror
      - RSYNC_DST=/rsync_dst/backup_for_remote
      - RSYNC_CRONTAB=0 0 * * *
      - RSYNC_UID=0
      - RSYNC_GID=0
      - RSYNC_OPTIONS=--archive --timeout=3600 --delete --stats -h
      - MAIL_TO=yyyyyyy@gmail.com
      - SMTP_ROOT=xxxxxx@gmail.com
      - SMTP_HOSTNAME=rsync-cron
      - SMTP_MAIL_HUB=smtp.gmail.com:587
      - SMTP_AUTH_USER=xxxxxxx@gmail.com 
      - SMTP_AUTH_PASS=xxxxxxxx 
    extra_hosts:
      - remote_host:192.168.7.241
    volumes:
      - backupVol:/rsync_dst
```

In the remote host you will need a rsync server. I use

```
  rsync-server:
    image: rugarci/rsync-server
    ports:
      - 873:8730 
    volumes:
      - /mnt/disk1:/export:ro
    restart: always
```

## About permissions

Depending on your volume store, permissions might be an issue. For example some
NAS implementations are very picky when it comes to the UID and GID of the
process reading/writing. As such you may need to specify a UID and GID that has
the correct permissions for the volumes. Note that these are the ID numbers,
not the names.
