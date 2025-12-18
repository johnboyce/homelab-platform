#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_cmd sudo
need_cmd tar

OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups"
mkdir -p "${OUT_DIR}"

TS="$(date +%Y-%m-%d_%H%M%S)"
ARCHIVE="${OUT_DIR}/host_snapshot_${TS}.tgz"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

log "== Creating inventory metadata =="
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/inventory.sh" > "${TMPDIR}/inventory.txt" || true

log "== Creating snapshot archive =="
sudo tar -czf "${ARCHIVE}"   /etc/nginx-docker   /etc/homelab/secrets   -C "${TMPDIR}" inventory.txt   2>/dev/null || true

log "✅ Snapshot created: ${ARCHIVE}"
