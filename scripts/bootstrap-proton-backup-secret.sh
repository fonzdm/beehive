#!/usr/bin/env bash

set -euo pipefail

namespace="${KUBERNETES_NAMESPACE:-home-assistant}"
secret_name="proton-drive-backup-gpg"
key_identity="Home Assistant Proton Backup <proton-backup@localhost>"

for command_name in gpg kubectl; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '%s is required\n' "$command_name" >&2
        exit 2
    fi
done

if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
    printf 'Kubernetes namespace does not exist or is not accessible: %s\n' "$namespace" >&2
    exit 2
fi

if kubectl -n "$namespace" get secret "$secret_name" >/dev/null 2>&1; then
    printf 'Secret %s/%s already exists; leaving it unchanged\n' "$namespace" "$secret_name"
    exit 0
fi

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
export GNUPGHOME="$work_dir/gnupg"
mkdir -m 0700 "$GNUPGHOME"

gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "$key_identity" rsa3072 cert,sign 0
fingerprint="$(gpg --batch --with-colons --list-secret-keys "$key_identity" \
    | awk -F: '$1 == "fpr" { print $10; exit }')"
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-add-key "$fingerprint" rsa3072 encr 0
gpg --batch --armor --export-secret-keys "$fingerprint" >"$work_dir/private-key.asc"

kubectl -n "$namespace" create secret generic "$secret_name" \
    --from-file=private-key.asc="$work_dir/private-key.asc"

printf 'Created cluster-only secret %s/%s\n' "$namespace" "$secret_name"
printf 'If the cluster is rebuilt, recreate this secret and authenticate Proton again.\n'
