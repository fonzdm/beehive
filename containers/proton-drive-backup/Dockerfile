FROM alpine:3.22.2@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412

ARG PROTON_DRIVE_VERSION=0.8.0
ARG PROTON_DRIVE_SHA256=51966bfe15eef265604a3561870f42ac0f03ac7adb13b6c3e418f919e3bba95c

RUN apk add --no-cache \
        bash \
        ca-certificates \
        gnupg \
        jq \
        libgcc \
        libstdc++ \
        pass \
        tzdata \
        wget \
    && wget -q -O /tmp/proton-drive \
        "https://proton.me/download/drive/cli/${PROTON_DRIVE_VERSION}/linux-x64-musl/proton-drive" \
    && printf '%s  %s\n' "$PROTON_DRIVE_SHA256" /tmp/proton-drive | sha256sum -c - \
    && install -m 0755 /tmp/proton-drive /usr/local/bin/proton-drive \
    && rm /tmp/proton-drive \
    && addgroup -g 65532 exporter \
    && adduser -D -H -u 65532 -G exporter exporter

COPY --chmod=0755 scripts/export-home-assistant-backups-proton.sh /usr/local/bin/export-home-assistant-backups-proton
COPY --chmod=0755 containers/proton-drive-backup/entrypoint.sh /usr/local/bin/proton-drive-backup-entrypoint

ENV GNUPGHOME=/tmp/gnupg \
    HOME=/state/home \
    PASSWORD_STORE_DIR=/state/password-store \
    PROTON_DRIVE_CACHE_DIR=/state/proton-drive \
    PROTON_DRIVE_CREDENTIALS_STORE=pass

USER 65532:65532
ENTRYPOINT ["/usr/local/bin/proton-drive-backup-entrypoint"]
CMD ["/usr/local/bin/export-home-assistant-backups-proton"]
