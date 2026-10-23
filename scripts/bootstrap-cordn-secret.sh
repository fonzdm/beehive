#!/usr/bin/env bash
# Requires kubectl and openssl. The coordinator identity goes directly to Kubernetes.
set -euo pipefail

if kubectl -n nostr get secret nostr-cordn-auth >/dev/null 2>&1; then
  echo 'nostr-cordn-auth already exists; keeping it.'
  exit 0
fi

kubectl get namespace nostr >/dev/null
# Never replace an existing identity: its public key identifies existing groups.
openssl rand -hex 32 | kubectl -n nostr create secret generic nostr-cordn-auth \
  --from-file=CORDN_SERVER_PRIVATE_KEY=/dev/stdin
