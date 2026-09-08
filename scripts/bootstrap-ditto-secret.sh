#!/usr/bin/env bash
# Requires kubectl and Docker. Credentials go directly to Kubernetes, not disk.
set -euo pipefail
if kubectl -n nostr get secret nostr-ditto-db-auth >/dev/null 2>&1; then
  echo 'nostr-ditto-db-auth already exists; keeping it.'
  exit 0
fi
kubectl get namespace nostr >/dev/null
# A failure to create the Secret never replaces an existing password.
docker run --rm -i python:3.12-slim sh -c 'pip install --quiet --disable-pip-version-check bcrypt==4.3.0 >&2 && python -' <<'PY' | kubectl create -f -
import bcrypt, json, secrets
password = secrets.token_urlsafe(48)
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
users = ('_meta:\n  type: internalusers\n  config_version: 2\n'
         'ditto:\n  hash: "' + hashed + '"\n  reserved: false\n  backend_roles: [admin]\n')
print(json.dumps({
    'apiVersion': 'v1', 'kind': 'Secret',
    'metadata': {'name': 'nostr-ditto-db-auth', 'namespace': 'nostr'},
    'type': 'Opaque', 'stringData': {'password': password, 'internal_users.yml': users}
}))
PY
