#!/usr/bin/env bash
set -Eeuo pipefail

ROLE="${1:-master}"
CLUSTER_NAME="${CLUSTER_NAME:-Cluster_1}"
CLUSTER_DIR="${PERSISTENT_ROOT}/${CONF_DIR}/${CLUSTER_NAME}"
TOKEN_FILE=/run/secrets/cluster_token
LOCK_FILE=/tmp/dst-prepare.lock

log() { printf '[dst:%s] %s\n' "${ROLE}" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

require_safe_value() {
  local name="$1" value="${!1-}"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || die "${name} must not contain newlines"
}

as_steam() {
  if [[ "$(id -u)" -eq 0 ]]; then
    gosu steam "$@"
  else
    "$@"
  fi
}

fix_permissions() {
  if [[ "$(id -u)" -eq 0 ]]; then
    install -d -o steam -g steam "${DST_INSTALL_DIR}" "${PERSISTENT_ROOT}/${CONF_DIR}"
    chown -R steam:steam "${DST_INSTALL_DIR}" "${PERSISTENT_ROOT}/${CONF_DIR}"
  fi
}

write_cluster_config() {
  local target="${CLUSTER_DIR}/cluster.ini"
  for name in SERVER_NAME SERVER_DESCRIPTION SERVER_PASSWORD GAME_MODE CLUSTER_INTENTION CLUSTER_KEY; do
    require_safe_value "$name"
  done
  cat >"${target}" <<EOF
[GAMEPLAY]
game_mode = ${GAME_MODE:-survival}
max_players = ${MAX_PLAYERS:-6}
pvp = ${PVP:-false}
pause_when_empty = ${PAUSE_WHEN_EMPTY:-true}

[NETWORK]
cluster_description = ${SERVER_DESCRIPTION:-A Dockerized DST server}
cluster_name = ${SERVER_NAME:-Docker DST Server}
cluster_password = ${SERVER_PASSWORD:-}
cluster_intention = ${CLUSTER_INTENTION:-cooperative}
cluster_language = ${SERVER_LANGUAGE:-en}

[MISC]
console_enabled = true

[SHARD]
shard_enabled = true
bind_ip = 0.0.0.0
master_ip = master
master_port = ${SHARD_MASTER_PORT:-10889}
cluster_key = ${CLUSTER_KEY:-docker-dst-cluster-key}
EOF
}

write_server_config() {
  local shard="$1" port="$2" is_master="$3" steam_port="$4" auth_port="$5"
  cat >"${CLUSTER_DIR}/${shard}/server.ini" <<EOF
[NETWORK]
server_port = ${port}

[SHARD]
is_master = ${is_master}
name = ${shard}

[STEAM]
master_server_port = ${steam_port}
authentication_port = ${auth_port}
EOF
}

copy_config_file() {
  local source="$1" target="$2"
  [[ -f "$source" ]] || die "missing required configuration file: ${source}"
  cp "$source" "$target"
}

prepare() {
  fix_permissions
  exec 9>"${LOCK_FILE}"
  flock 9

  [[ -s "$TOKEN_FILE" ]] || die "cluster token is missing; copy secrets/cluster_token.txt.example and insert your Klei token"
  log "updating dedicated server with SteamCMD"
  as_steam "${STEAMCMD_DIR}/steamcmd.sh" \
    +force_install_dir "${DST_INSTALL_DIR}" \
    +login anonymous \
    +app_update 343050 validate \
    +quit

  install -d -o steam -g steam "${CLUSTER_DIR}/Master" "${CLUSTER_DIR}/Caves" "${DST_INSTALL_DIR}/mods"
  write_cluster_config
  write_server_config Master "${MASTER_PORT:-10999}" true "${MASTER_STEAM_PORT:-27018}" "${MASTER_AUTH_PORT:-8768}"
  write_server_config Caves "${CAVES_PORT:-11000}" false "${CAVES_STEAM_PORT:-27019}" "${CAVES_AUTH_PORT:-8769}"
  tr -d '\r\n' <"${TOKEN_FILE}" >"${CLUSTER_DIR}/cluster_token.txt"

  copy_config_file /config/Master/worldgenoverride.lua "${CLUSTER_DIR}/Master/worldgenoverride.lua"
  copy_config_file /config/Caves/worldgenoverride.lua "${CLUSTER_DIR}/Caves/worldgenoverride.lua"
  copy_config_file /config/mods/modoverrides.lua "${CLUSTER_DIR}/Master/modoverrides.lua"
  copy_config_file /config/mods/modoverrides.lua "${CLUSTER_DIR}/Caves/modoverrides.lua"
  copy_config_file /config/mods/dedicated_server_mods_setup.lua "${DST_INSTALL_DIR}/mods/dedicated_server_mods_setup.lua"
  chown -R steam:steam "${CLUSTER_DIR}" "${DST_INSTALL_DIR}/mods"
  log "server files and configuration are ready"
}

run_shard() {
  local shard="$1"
  fix_permissions
  [[ -x "${DST_INSTALL_DIR}/bin64/dontstarve_dedicated_server_nullrenderer_x64" ]] || die "server is not installed; run the prepare service first"
  [[ -s "${CLUSTER_DIR}/cluster_token.txt" ]] || die "cluster configuration is not prepared"
  log "starting ${shard} shard"
  cd "${DST_INSTALL_DIR}/bin64"
  exec gosu steam ./dontstarve_dedicated_server_nullrenderer_x64 \
    -persistent_storage_root "${PERSISTENT_ROOT}" \
    -conf_dir "${CONF_DIR}" \
    -cluster "${CLUSTER_NAME}" \
    -shard "${shard}"
}

case "${ROLE,,}" in
  prepare) prepare ;;
  master) run_shard Master ;;
  caves) run_shard Caves ;;
  *) die "unknown role: ${ROLE} (expected prepare, master, or caves)" ;;
esac
