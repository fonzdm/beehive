# Home Assistant recovery model

Home Assistant uses two complementary recovery layers:

1. Git contains reusable, non-sensitive configuration.
2. Encrypted Home Assistant backups contain runtime state and private household
   data.

Neither the local RAID nor a retained PVC is an off-site backup.

## Configuration in Git

The deployment mounts these files read-only from the
`home-assistant-configuration` ConfigMap:

- `configuration.yaml`
- `packages/location_history.yaml`
- `packages/reolink_events.yaml`

`location_history.yaml` owns the generic date/time helpers, quick-range selector,
and automation used by the location-history views. It intentionally contains no
device, person, tracker, sensor, or household names.

The location-history frontend currently depends on these HACS dashboard packages:

| Repository | Pinned version |
| --- | --- |
| `nathan-gs/ha-map-card` | `v1.16.0` |
| `KipK/a-better-history-card` | `0.3.1` |
| `diestrohs/datetime-spinner-card` | `v0.2.2` |
| `iantrich/config-template-card` | `1.3.6` |

The HACS downloads and Lovelace resource registry live on the Home Assistant data
PVC. Reinstall the versions above after a blank-volume recovery, then restore the
encrypted backup.

## Configuration intentionally excluded from Git

The following data contains private identifiers or credentials and must only be
restored from an encrypted backup:

- device and entity registries;
- mobile-app registrations and authentication data;
- dashboards containing device/entity references;
- HACS state and the Lovelace resource registry;
- backup encryption keys and cloud sessions;
- recorder history and location history.

Do not export `.storage` files into Git, even if individual values appear harmless.

## Local backup policy

Home Assistant creates an encrypted automatic backup daily and retains seven local
copies in `/config/backups`. These archives include the recorder database. Because
the directory is on `home-assistant-data`, all local copies share the same failure
domain as Home Assistant and must be exported off-cluster.

## Proton Drive off-site export

Use Proton's official Drive CLI rather than the deprecated rclone Proton backend.
The CLI supports Linux, scripted uploads, and end-to-end encryption, but requires a
one-time browser login and stores a renewable session in an OS secret store. Proton's
public CLI documentation does not state that a Business subscription is required;
authenticate the intended Proton Unlimited account once before enabling automation.

The intended export flow is:

1. Authenticate the official CLI interactively on a trusted runner.
2. Store its session outside Git in a proper secret store.
3. Upload only new `/config/backups/*.tar` files to a dedicated Proton Drive folder.
4. List the remote folder after each run and verify that every local archive name and
   original size is present.
5. Alert on failed uploads and periodically test a restore with the backup emergency
   kit.

Do not use the CLI's `unsafe_file` credential store and do not commit an authenticated
CLI cache or session. Until the Proton account is authenticated and an exporter is
enabled, the backups remain local-only.

The repository includes
[`export-home-assistant-backups-proton.sh`](../../../scripts/export-home-assistant-backups-proton.sh)
for the scheduled export step. It refuses to upload archives newer than five
minutes, skips names already present in Proton Drive, and verifies every local
filename and original size against the remote directory after uploading.

The runner needs the official `proton-drive` binary, `jq`, read-only access to the
Home Assistant backup directory, and access to the same OS secret store used during
interactive login. Configure it with:

```bash
export HOME_ASSISTANT_BACKUP_DIR=/config/backups
export PROTON_DRIVE_DESTINATION='/my-files/Home Assistant Backups'
export PROTON_DRIVE_CREDENTIALS_STORE=keychain
scripts/export-home-assistant-backups-proton.sh
```

Create the remote folder once before scheduling the script:

```bash
proton-drive filesystem create-folder /my-files 'Home Assistant Backups'
```

The destination name above is only an example and is not coupled to the Home
Assistant installation. A scheduler should run the exporter after the daily Home
Assistant backup window and alert on any non-zero exit status.

Run that scheduler as a Kubernetes `CronJob`, not as a Home Assistant automation.
Home Assistant remains responsible only for creating and retaining its encrypted
local backups. The independent `CronJob` mounts `home-assistant-data` read-only at
the backup path and uses a separate persistent Proton CLI state directory. This
keeps export failures visible to Kubernetes and allows exports to continue whenever
Home Assistant's UI or automation engine is unhealthy.

## Proton Drive authentication and recovery

The enabled CronJob runs at minute 17 every six hours in the `Europe/Rome` time
zone. Its session is encrypted with `pass`; the GPG private key is kept in a
cluster-only Kubernetes Secret and is never committed to Git. The separate state
PVC contains only the encrypted session and disposable CLI caches.

Authentication is normally required only after first deployment or loss of the
state PVC. From a trusted workstation with the repository checked out, `gpg`, and
`kubectl` configured for this cluster, start the temporary bootstrap Pod between
scheduled export times:

```bash
scripts/bootstrap-proton-backup-secret.sh
kubectl apply -f kubernetes/apps/home-assistant/proton-backup-bootstrap-pod.yaml
kubectl -n home-assistant wait --for=condition=Ready \
  pod/proton-drive-bootstrap --timeout=5m
kubectl -n home-assistant exec -it proton-drive-bootstrap -- \
  proton-drive auth login
```

Open the URL printed by the final command, sign in to the Proton Unlimited account,
and leave the terminal open until it reports success. Then create and verify the
dedicated destination:

```bash
kubectl -n home-assistant exec -it proton-drive-bootstrap -- \
  proton-drive filesystem create-folder /my-files 'Home Assistant Backups'
kubectl -n home-assistant exec proton-drive-bootstrap -- \
  proton-drive filesystem list '/my-files/Home Assistant Backups'
```

If the folder already exists, the create command can fail harmlessly; the list must
succeed. Delete the temporary Pod after login and run an immediate test Job before
relying on the six-hour schedule.

The exporter never deletes remote backups. Any future retention policy must be
implemented and tested separately, with deletion disabled by default.
