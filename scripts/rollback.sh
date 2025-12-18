#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_cmd git

REF="${1:-}"
[[ -n "${REF}" ]] || die "Usage: scripts/rollback.sh <git-ref>"

log "== Rollback desired state to: ${REF} =="

CURRENT="$(git rev-parse --short HEAD 2>/dev/null || true)"
[[ -n "${CURRENT}" ]] || die "Not inside a git repository."

log "Current ref: ${CURRENT}"

if [[ -n "$(git status --porcelain)" ]]; then
  warn "Working tree not clean. Rollback will still proceed."
fi

git fetch --all --tags >/dev/null 2>&1 || true
git checkout "${REF}"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy_edge_nginx.sh"
log "✅ Rollback complete."
