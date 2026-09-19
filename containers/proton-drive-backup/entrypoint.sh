#!/usr/bin/env bash

set -euo pipefail
umask 077

private_key=/run/secrets/proton-drive-gpg/private-key.asc

if [[ ! -r "$private_key" ]]; then
    printf 'Proton Drive GPG private key is not mounted at %s\n' "$private_key" >&2
    exit 2
fi

mkdir -p "$GNUPGHOME" "$HOME" "$PASSWORD_STORE_DIR" "$PROTON_DRIVE_CACHE_DIR"
gpg --batch --quiet --import "$private_key"
fingerprint="$(gpg --batch --with-colons --show-keys "$private_key" \
    | awk -F: '$1 == "fpr" { print $10; exit }')"

if [[ -z "$fingerprint" ]]; then
    printf 'Could not determine the Proton Drive credential-encryption key\n' >&2
    exit 2
fi

# The private key is supplied by our cluster Secret, so explicitly trust it for
# unattended encryption after importing it into each pod's ephemeral keyring.
printf '%s:6:\n' "$fingerprint" | gpg --batch --import-ownertrust >/dev/null

if [[ ! -f "$PASSWORD_STORE_DIR/.gpg-id" ]]; then
    pass init "$fingerprint" >/dev/null
fi

exec "$@"
