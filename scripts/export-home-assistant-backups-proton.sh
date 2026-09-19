#!/usr/bin/env bash

set -euo pipefail

backup_dir="${HOME_ASSISTANT_BACKUP_DIR:-/config/backups}"
destination="${PROTON_DRIVE_DESTINATION:-}"
proton_drive_bin="${PROTON_DRIVE_BIN:-proton-drive}"
minimum_age_minutes="${BACKUP_MINIMUM_AGE_MINUTES:-5}"

if [[ -z "$destination" || "$destination" != /my-files/* ]]; then
    printf 'PROTON_DRIVE_DESTINATION must be an existing path below /my-files\n' >&2
    exit 2
fi

if [[ ! -d "$backup_dir" ]]; then
    printf 'Home Assistant backup directory does not exist: %s\n' "$backup_dir" >&2
    exit 2
fi

if ! command -v "$proton_drive_bin" >/dev/null 2>&1; then
    printf 'Proton Drive CLI is not executable: %s\n' "$proton_drive_bin" >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required to verify the remote backup names and sizes\n' >&2
    exit 2
fi

if [[ ! "$minimum_age_minutes" =~ ^[0-9]+$ ]]; then
    printf 'BACKUP_MINIMUM_AGE_MINUTES must be a non-negative integer\n' >&2
    exit 2
fi

declare -a archives=()
now="$(date +%s)"
for archive in "$backup_dir"/*.tar; do
    [[ -e "$archive" ]] || continue

    modified="$(stat -c %Y "$archive")"
    if (( now - modified >= minimum_age_minutes * 60 )); then
        archives+=("$archive")
    fi
done

if (( ${#archives[@]} == 0 )); then
    printf 'No completed Home Assistant backup archives found in %s\n' "$backup_dir"
    exit 0
fi

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

# Listing first validates both the stored login session and the destination. It
# also avoids asking Proton to resolve the same filename conflicts every run.
"$proton_drive_bin" filesystem list --json "$destination" >"$work_dir/remote-files-before.json"

declare -a pending_archives=()
for archive in "${archives[@]}"; do
    name="${archive##*/}"
    size="$(stat -c %s "$archive")"

    if jq -e \
        --arg name "$name" \
        --argjson size "$size" \
        'any(.[];
            .type == "file"
            and .name.ok == true
            and .name.value == $name
            and .activeRevision.claimedSize == $size
        )' \
        "$work_dir/remote-files-before.json" >/dev/null; then
        continue
    fi

    if jq -e \
        --arg name "$name" \
        'any(.[]; .type == "file" and .name.ok == true and .name.value == $name)' \
        "$work_dir/remote-files-before.json" >/dev/null; then
        printf 'Remote file %s exists with a different size; refusing to overwrite it\n' "$name" >&2
        exit 1
    fi

    pending_archives+=("$archive")
done

if (( ${#pending_archives[@]} > 0 )); then
    "$proton_drive_bin" filesystem upload \
        --json \
        --file-conflict-strategy skip \
        --skip-thumbnails \
        "${pending_archives[@]}" \
        "$destination" | tee "$work_dir/upload-summary.json"

    if ! jq -e '.failedItems == 0' "$work_dir/upload-summary.json" >/dev/null; then
        printf 'Proton Drive reported one or more failed uploads\n' >&2
        exit 1
    fi
else
    printf 'All completed archives are already present in Proton Drive\n'
fi

"$proton_drive_bin" filesystem list --json "$destination" >"$work_dir/remote-files.json"

for archive in "${archives[@]}"; do
    name="${archive##*/}"
    size="$(stat -c %s "$archive")"

    if ! jq -e \
        --arg name "$name" \
        --argjson size "$size" \
        'any(.[];
            .type == "file"
            and .name.ok == true
            and .name.value == $name
            and .activeRevision.claimedSize == $size
        )' \
        "$work_dir/remote-files.json" >/dev/null; then
        printf 'Remote verification failed for %s (%s bytes)\n' "$name" "$size" >&2
        exit 1
    fi
done

printf 'Verified %s Home Assistant backup archive(s) in %s\n' \
    "${#archives[@]}" "$destination"
