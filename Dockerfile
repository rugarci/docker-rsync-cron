ARG ALPINE_BASE=3.21.2

FROM alpine:${ALPINE_BASE}

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF

LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="docker-rsync-cron" \
    org.label-schema.version=$VERSION \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/rugarci/docker-rsync-cron" \
    org.label-schema.vcs-type="Git" \
    org.label-schema.schema-version="1.0"

RUN apk --no-cache add apprise ssmtp mailx gettext rsync tzdata sudo

ENV CRONTAB_ENTRY="" \
    RSYNC_CRONTAB="0 0 * * *" \
    RSYNC_OPTIONS="--archive --timeout=3600" \
    RSYNC_UID="0" \
    RSYNC_GID="0"

VOLUME ["/rsync_src", "/rsync_dst"]

ADD ssmtp.conf.tmpl /etc/ssmtp/ssmtp.conf.tmpl
COPY rsync-entrypoint.sh /entrypoint.d/rsync.sh
COPY docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["sh", "/entrypoint.sh"]
