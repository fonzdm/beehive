# Nostr

The relay is configured at `wss://relay.nostr.fonzdm.xyz` in namespace
`nostr`. Its owner is:

```text
npub126e0s98qpx0688yfy46qrg4c59zuyf6srjfxvr2mtt8vu8xmvsaqps4r8s
```

**Temporary Amber test mode:** the owner-key restrictions on subscriptions and
publishing are removed. Any client that can reach the relay can read stored events
and publish valid events without authenticating. Access currently relies on the
operator's LAN/VPN boundary, which is not enforced by these app manifests.
NIP-42 remains available, but is optional. Metrics, COUNT and search remain disabled.
No private key is stored on the server or in this repository. This temporary mode
does not automatically expire; restore the restrictions below after testing.

## Amber pairing test

With both devices on the LAN/VPN, add `wss://relay.nostr.fonzdm.xyz` in Amber's
Settings → Relays → Active relays. Amber's test uses a fresh transport key to
publish and receive a kind-24133 event without owner authentication.

Create a bunker connection in Amber using this relay, then use the generated
`bunker://` link in a NIP-46-compatible client and approve pairing/signing in
Amber. Keep the link's pairing secret private. Your nsec stays in Amber.
For Amethyst on the same phone, login using Amber's Android signer integration
(NIP-55); a remote-signing relay is not required for that local flow.

## Deployment

The parent Flux apps Kustomization discovers this directory. Its child
`nostr/nostr-relay` Kustomization installs the Helm release. The existing Traefik
HTTPS listener routes the hostname to port 8080, including WebSocket upgrades.
The gateway certificate includes `*.nostr.fonzdm.xyz`.

Create a DNS record for `relay.nostr.fonzdm.xyz` pointing at the existing Traefik
ingress address in the DNS zone used by your clients. DNS records are not managed
in this repository. This hostname did not resolve from the development environment
during setup; the existing `ha.cloud.fonzdm.xyz` resolved to `172.16.0.1` there.

After these manifests reach the Flux source branch, check:

```sh
flux get kustomizations -n nostr
flux get helmreleases -n nostr
kubectl -n nostr get pods,pvc,httproute
kubectl -n ingress get certificate wildcard-apps
curl -H 'Accept: application/nostr+json' https://relay.nostr.fonzdm.xyz/
```

Confirm that the HTTPRoute has `Accepted=True` and `ResolvedRefs=True`, then
connect using your Nostr client. During the temporary Amber test, reading and
publishing do not require NIP-42 authentication.

## Chart and updates

[Rnostr](https://github.com/rnostr/rnostr) provides separate authenticated-public-key
allowlists for reads and writes in its
[official configuration](https://github.com/rnostr/rnostr/blob/v0.4.9/rnostr.example.toml).
No maintained dedicated Rnostr chart was found. The dedicated strfry charts found
do not supply the same complete private-read allowlist in strfry's built-in settings.
This deployment uses [bjw-s app-template](https://github.com/bjw-s-labs/helm-charts)
5.1.0 and the official `rnostr/rnostr:v0.4.9` image, published June 6, 2026,
pinned to its registry digest. The image currently supports amd64, so the pod
selects that architecture.

The ImageRepository and ImagePolicy in
`../../talos/flux-system/image-updater.yaml` track stable `0.4.x` releases and
digest changes. The existing ImageUpdateAutomation updates the image setters on
`flux-auto-images-updates`; the existing PR workflow promotes those changes for
review. Minor/major upgrades require deliberately widening the policy range.

## Storage and access changes

The relay uses one replica and Recreate upgrades to avoid simultaneous writers
on the 10 GiB `localpv-raid` LMDB volume. The PVC is retained when Flux prunes the
app. Back up the volume with the relay stopped before upgrading or restoring;
the local volume and its retention annotation are not backups.

To restore owner-only access, add both sections below to the `rnostr.toml`
ConfigMap data in `relay/deployment/release.yaml`, leaving `auth.enabled = true`:

```toml
[auth.req]
pubkey_whitelist = ["56b2f814e0099fa39c89257401a2b8a145c227501c92660d5b5acece1cdb643a"]

[auth.event]
pubkey_whitelist = ["56b2f814e0099fa39c89257401a2b8a145c227501c92660d5b5acece1cdb643a"]
```

Also restore the relay description to indicate owner authentication is required.
The chart's ConfigMap checksum rolls the pod when configuration changes, closing
existing connections. Restoring these restrictions also blocks Amber's anonymous
transport test and unallowlisted remote-signing connection keys again.

## Blossom file storage

`https://blossom.nostr.fonzdm.xyz` serves Blossom separately from the relay,
using the official `ghcr.io/hzrd149/blossom-server:6.2.0` image and app-template
5.1.0. Its Flux Kustomization and HelmRelease are named `nostr-blossom`.
The existing wildcard certificate covers this hostname. Configure clients to use
this HTTPS URL as their Blossom server; it is not a WebSocket relay URL.
DNS currently resolves to the private ingress address `172.16.0.1`.

Uploads require a BUD-11 kind-24242 signed authorization event from the owner
pubkey above. A compatible client can request signatures through Amber; no nsec
is stored here. The upload limit is 100 MiB with one worker and two concurrent
jobs. Deletion requires a signed authorization and blob ownership. Listing,
mirroring, media processing, reports, the landing page, and administration UI
are disabled. A request to `/` returning 404 is expected.

Downloads by hash are unauthenticated. Access relies on the existing LAN/VPN
boundary, not a network restriction created by these manifests. Before storing
private documents, encrypt their contents and sensitive metadata in the client;
a file hash is not an authorization policy. Adding this server to a client's
server list does not encrypt its uploads automatically.

### Retention and startup adapter

Version 6.2.0 requires an `expiration` on the same storage rules used for uploader
allowlists and does not offer a pruning disable switch. `bootstrap.ts` starts
upstream's database, local storage, workers and HTTP server without starting its
pruning loop. The schema-required `expiration: 100 years` is therefore unused:
**files do not expire automatically**. Explicit authenticated deletion still works.
Do not switch back to upstream's default entrypoint with this configuration.

The adapter is limited to local storage/database with the dashboard disabled;
review it before changing those settings. The ConfigMap is passed through Helm
values so changes trigger a pod rollout. Flux image automation follows stable
6.2.x versions and digest changes through the existing image-update PR workflow.
Review the adapter against upstream `main.ts` when upgrading, and remove it once
upstream supports disabling expiry independently of uploader allowlists.

### Storage and backups

The 50 GiB `nostr-blossom-data` localpv-raid PVC holds both `/app/data/blobs` and
`/app/data/sqlite.db` (including SQLite WAL files). One replica and Recreate
upgrades avoid concurrent writers. The PVC is retained on Flux pruning.
Local storage capacity enforcement depends on the provisioner/filesystem; the
PVC request is not an application-level per-user quota.

No scheduled off-cluster backup destination is configured in this repository.
The retained PVC and RAID are not backups. For a consistent manual backup,
suspend this HelmRelease's reconciliation, scale its Deployment to zero, and
archive the entire PVC using a temporary pod mounting the claim. Copy the archive
off-cluster, remove the temporary pod, then resume/reconcile the HelmRelease.
Restore the full directory, not just the blob files. Schedule backups before
using this for irreplaceable files.

### Validation

Check `flux get helmreleases -n nostr`, the pod/PVC, and HTTPRoute conditions
(`Accepted=True`, `ResolvedRefs=True`). A TLS request to the disabled root page
should return HTTP 404, not a TLS or gateway error. Test an actual upload using
your Blossom client and Amber, if possible.

Deployment validation used the pinned image with the pod's non-root/read-only
security settings. Disposable identities exercised rejected anonymous/unlisted
uploads, an allowed upload, the size limit, disabled endpoints, byte retrieval,
owner-only deletion, and retention without the pruning loop. Production owner
signatures are deliberately left to the client; no private key was requested.
