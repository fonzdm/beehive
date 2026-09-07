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
