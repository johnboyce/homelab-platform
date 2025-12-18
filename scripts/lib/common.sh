#!/usr/bin/env bash
set -euo pipefail

log()  { printf "\033[1m%s\033[0m\n" "$*"; }
warn() { printf "\033[33mWARN:\033[0m %s\n" "$*"; }
die()  { printf "\033[31mERR:\033[0m %s\n" "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

load_env_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$f"; set +a
  fi
}
