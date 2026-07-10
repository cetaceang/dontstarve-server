#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
archive="$(realpath "${1:?usage: restore.sh <backup.tar.gz>}")"
[[ -f "$archive" ]] || { echo "Backup not found: $archive" >&2; exit 1; }

# Refuse archives containing absolute paths or parent traversal.
if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  echo "Unsafe paths found in backup archive" >&2
  exit 1
fi
tar -tzf "$archive" | grep -q '^cluster/' || {
  echo "Archive does not contain the expected cluster/ directory" >&2
  exit 1
}

echo "Stopping both shards..."
docker compose stop master caves

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p backups
echo "Creating a safety backup before restore..."
docker compose run --rm --no-deps \
  --entrypoint tar \
  -v "$(pwd)/backups:/backup" \
  prepare -czf "/backup/pre-restore-${stamp}.tar.gz" -C /data cluster

echo "Restoring $archive..."
docker compose run --rm --no-deps \
  --entrypoint /bin/bash \
  -v "${archive}:/restore/archive.tar.gz:ro" \
  prepare -Eeuc 'rm -rf /data/cluster && tar -xzf /restore/archive.tar.gz -C /data && chown -R steam:steam /data/cluster'

echo "Re-applying configuration and checking the server installation..."
docker compose run --rm prepare
docker compose up -d --no-deps master
docker compose up -d --no-deps caves
echo "Restore complete. Safety backup: backups/pre-restore-${stamp}.tar.gz"

