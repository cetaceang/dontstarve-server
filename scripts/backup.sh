#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p backups
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="dst-cluster-${stamp}.tar.gz"

echo "Stopping both shards for a consistent backup..."
docker compose stop master caves

restart() {
  echo "Starting both shards..."
  docker compose up -d --no-deps master
  docker compose up -d --no-deps caves
}
trap restart EXIT

docker compose run --rm --no-deps \
  --entrypoint tar \
  -v "$(pwd)/backups:/backup" \
  prepare -czf "/backup/${archive}" -C /data cluster

(cd backups && sha256sum "${archive}" >"${archive}.sha256")
echo "Backup written to backups/${archive}"

