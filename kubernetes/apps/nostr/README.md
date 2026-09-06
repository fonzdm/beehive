# Nostr

The private relay is configured at `wss://relay.nostr.fonzdm.xyz` in namespace
`nostr`. Use a client that supports NIP-42 authentication and sign in with:

```text
npub126e0s98qpx0688yfy46qrg4c59zuyf6srjfxvr2mtt8vu8xmvsaqps4r8s
```

Both subscriptions and publishing require this authenticated identity. The owner
can store events authored by other identities (for example, archived events).
Anonymous clients and other authenticated identities cannot read or write events.
The HTTP relay information document is public; metrics, COUNT and search are disabled.
No private key is stored on the server or in this repository.

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
connect using your authenticated Nostr client. Merely establishing a WebSocket
connection does not grant access to events.

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

To change access, edit **both** `auth.req.pubkey_whitelist` and
`auth.event.pubkey_whitelist` in `relay/deployment/release.yaml`. They use
64-character hexadecimal public keys. The chart's ConfigMap checksum rolls the
pod when configuration changes, closing existing authenticated connections.
