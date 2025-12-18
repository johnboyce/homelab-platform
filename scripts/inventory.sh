#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_cmd docker

echo "== Inventory =="
date -Is
echo

echo "== Docker version =="
docker --version
echo

echo "== Docker compose version =="
docker compose version || true
echo

echo "== Networks =="
docker network ls
echo

echo "== Containers (running) =="
docker ps
