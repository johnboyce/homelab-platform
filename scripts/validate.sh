#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

load_env_if_exists "/etc/homelab/secrets/global.env"
load_env_if_exists "/etc/homelab/secrets/nginx.env"

need_cmd docker
need_cmd curl

NGINX_CONTAINER="${NGINX_CONTAINER:-geek-nginx}"
CERT_HOST_DIR="${CERT_HOST_DIR:-/etc/nginx-docker/certs}"

log "== Validate host contract =="

[[ -d /etc/nginx-docker ]] || die "Missing: /etc/nginx-docker"

log "== Validate cert location =="
if [[ -d "${CERT_HOST_DIR}" ]]; then
  echo "CERT_HOST_DIR=${CERT_HOST_DIR}"
else
  warn "CERT_HOST_DIR directory not found: ${CERT_HOST_DIR}"
fi

log "== Validate nginx container running =="
docker ps --format '{{.Names}}' | grep -qx "${NGINX_CONTAINER}" || die "Nginx container not running: ${NGINX_CONTAINER}"

log "== nginx -t (inside container) =="
docker exec "${NGINX_CONTAINER}" nginx -t

log "== Smoke tests (HTTP Host headers) =="
PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-example.com}"
curl -fsS -o /dev/null -H "Host: geek" http://127.0.0.1 && echo "OK: Host geek"
curl -fsS -o /dev/null -H "Host: auth.${PUBLIC_DOMAIN}" http://127.0.0.1 && echo "OK: Host auth.${PUBLIC_DOMAIN}"

log "✅ Validate complete."
