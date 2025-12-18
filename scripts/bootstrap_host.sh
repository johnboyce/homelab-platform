#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

log "== homelab-platform: host bootstrap =="

SECRETS_DIR="/etc/homelab/secrets"
NGINX_DOCKER_DIR="/etc/nginx-docker"
NETWORK_NAME="geek-infra"

need_cmd sudo
need_cmd docker

log "Creating secrets dir: ${SECRETS_DIR}"
sudo mkdir -p "${SECRETS_DIR}"
sudo chown root:root "${SECRETS_DIR}"
sudo chmod 700 "${SECRETS_DIR}"

log "Ensuring nginx-docker dir exists: ${NGINX_DOCKER_DIR}"
sudo mkdir -p "${NGINX_DOCKER_DIR}"/{conf.d,snippets,sites-available,sites-enabled,certs}
sudo chown -R root:root "${NGINX_DOCKER_DIR}"
sudo chmod 755 "${NGINX_DOCKER_DIR}"
sudo chmod 700 "${NGINX_DOCKER_DIR}/certs"

log "Creating shared Docker network (explicit): ${NETWORK_NAME}"
if docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
  warn "Network already exists: ${NETWORK_NAME}"
else
  docker network create "${NETWORK_NAME}" >/dev/null
  log "✅ Network created: ${NETWORK_NAME}"
fi

log "✅ Host bootstrap complete."
log "Next:"
log "  - Place host-only env files under: ${SECRETS_DIR}"
log "  - Place TLS certs under your chosen CERT_HOST_DIR (see env/examples/nginx.env.example)"
log "  - Run: make deploy-edge"
