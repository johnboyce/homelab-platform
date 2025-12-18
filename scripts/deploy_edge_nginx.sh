#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${REPO_ROOT}/stacks/00-edge/nginx/etc-nginx-docker"
DEST="/etc/nginx-docker"

load_env_if_exists "/etc/homelab/secrets/global.env"
load_env_if_exists "/etc/homelab/secrets/nginx.env"

NGINX_CONTAINER="${NGINX_CONTAINER:-geek-nginx}"
PROMPT_RELOAD="${PROMPT_RELOAD:-0}"
AUTO_RELOAD="${AUTO_RELOAD:-0}"

need_cmd sudo
need_cmd rsync
need_cmd docker

log "== Deploy edge nginx config (repo → host) =="
echo "Source: ${SOURCE}"
echo "Dest:   ${DEST}"
echo "Nginx:  ${NGINX_CONTAINER}"
echo

[[ -d "${SOURCE}" ]] || die "Source directory missing: ${SOURCE}"

if ! docker ps --format '{{.Names}}' | grep -qx "${NGINX_CONTAINER}"; then
  die "Nginx container not running: ${NGINX_CONTAINER}"
fi

ts="$(date +%F_%H%M%S)"
backup="/etc/nginx-docker.BAK.deploy.${ts}"

log "== Backup current ${DEST} to ${backup} (excluding certs contents) =="
sudo mkdir -p "${backup}"
if [[ -d "${DEST}" ]]; then
  sudo rsync -a --delete --exclude 'certs/*' "${DEST}/" "${backup}/"
fi
log "✅ Backup complete"

log "== Syncing config to host (excluding certs/) =="
sudo mkdir -p "${DEST}"
sudo rsync -a --delete --exclude 'certs/' "${SOURCE}/" "${DEST}/"

sudo mkdir -p "${DEST}/certs"
sudo chown -R root:root "${DEST}" || true
sudo chmod 700 "${DEST}/certs" || true

log "== Nginx config test inside container =="
docker exec "${NGINX_CONTAINER}" nginx -t

if [[ "${AUTO_RELOAD}" == "1" ]]; then
  docker exec "${NGINX_CONTAINER}" nginx -s reload
  log "✅ Nginx reloaded (AUTO_RELOAD=1)"
elif [[ "${PROMPT_RELOAD}" == "1" ]]; then
  read -p "Reload nginx now? [y/N] " -n 1 -r
  echo
  if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
    docker exec "${NGINX_CONTAINER}" nginx -s reload
    log "✅ Nginx reloaded"
  else
    warn "Skipped reload"
  fi
else
  warn "Reload skipped (set AUTO_RELOAD=1 or PROMPT_RELOAD=1)"
fi
