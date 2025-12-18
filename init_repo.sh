#!/usr/bin/env bash
set -euo pipefail

# homelab-platform: repo initializer / updater
# - Idempotent: safe to re-run
# - Stack-first: compose and templates live under stacks/
# - Host-only secrets: never written by this script

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}"

say() { printf "\n\033[1m%s\033[0m\n" "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ Missing required command: $1"
    exit 1
  }
}

need_cmd mkdir
need_cmd cat

say "== homelab-platform: initializing/updating repo structure =="
echo "Repo root: ${REPO_ROOT}"

# ------------------------------------------------------------------------------
# Directories
# ------------------------------------------------------------------------------
say "== Creating directories =="
mkdir -p \
  docs \
  env/examples \
  scripts/lib \
  stacks/00-edge/nginx/etc-nginx-docker/{conf.d,snippets,sites-available,sites-enabled} \
  stacks/00-edge/nginx \
  stacks/10-auth/authentik \
  stacks/20-apps/bookstack \
  backups

# ------------------------------------------------------------------------------
# .gitignore
# ------------------------------------------------------------------------------
say "== Writing .gitignore =="
cat > .gitignore <<'EOF'
# -------------------------------------------------------------------
# Secrets and credentials MUST NOT be committed
# -------------------------------------------------------------------
**/*.env
.env
.env.*
**/secrets/**
secrets/**

# Private keys / certs
**/*.key
**/*.pem
**/*.pfx
**/*.p12
**/*.crt
**/certs/**
/etc-nginx-docker/certs/**

# Backups produced locally on host
backups/**
*.tgz
*.tar.gz

# OS/editor noise
.DS_Store
.idea/
.vscode/
*.swp

# Logs
*.log
EOF

# ------------------------------------------------------------------------------
# ADMIN.md (Copilot-agent rules + platform contract)
# ------------------------------------------------------------------------------
say "== Writing ADMIN.md =="
cat > ADMIN.md <<'EOF'
# ADMIN.md — GEEK Home Platform (homelab-platform)

This repository is a **production-quality, reusable homelab platform** built around:
- Docker-first stacks
- Nginx reverse proxy (edge)
- Authentik SSO (identity)
- Clear LAN vs WAN trust boundaries
- **No secrets in git**
- Everything reproducible and documented

This file exists to provide **precise rules and context** for admins and for GitHub Copilot agent / code generation tools.

---

## 1) Golden rules

### 1.1 No secrets in git — ever
**Never** commit:
- certs, private keys
- tokens (Authentik outpost tokens, API keys)
- real `.env` files

Repo contains:
- `env/examples/*.env.example` only
- templates/reference configs only

Host contains:
- real env files (not git)
- TLS certificates (not git)

If a change requires a secret, document it and require the operator to place it on-host.

### 1.2 Repo is source-of-truth for desired state
- Compose files and reference configs live in this repo.
- The host is updated only through the scripts in `scripts/`.
- Avoid “manual edits” on the host. If a manual change is necessary, write it into a script and document it.

### 1.3 Stack-first architecture
All deployable units live under `stacks/` and are ordered by prefix:

- `stacks/00-edge/*` ingress/foundation
- `stacks/10-auth/*` identity/SSO
- `stacks/20-apps/*` applications
- optional higher numbers for experiments

Each stack:
- has its own `docker-compose.yml`
- has `.env.example` or references `env/examples/*`
- has a README describing required host prerequisites

### 1.4 Explicit networking — no implicit Docker surprises
A shared Docker network **must** be created explicitly by script (not as a side-effect of compose):
- Network name: `geek-infra`

All platform containers that must communicate (nginx, authentik, apps) attach to this network.
Nginx must proxy upstreams by **service name**, never by host IP.

### 1.5 Nginx mounts are minimal (do not mount all of /etc/nginx)
Mount only:
- `nginx.conf`
- `conf.d/` or `sites-enabled/`
- `snippets/`
- `certs/` (read-only)

Mounting the entire `/etc/nginx` into the container is known-bad.

---

## 2) Host contracts (portable defaults)

Operators may use any hostname/domain. The defaults below are used in documentation and examples.

### 2.1 Host paths (authoritative runtime)
- Live nginx config: `/etc/nginx-docker/`
- Real env files (host-only): `/etc/homelab/secrets/`
- Backups created by scripts: `./backups/` (repo-local, gitignored)

### 2.2 TLS certificates (host-only)
The repo does **not** enforce a single certificate location.
Two supported patterns:
- A) `/etc/nginx-docker/certs/` (simplest)
- B) `/etc/ssl/homelab/<domain>/` (cleaner separation)

If you change cert location, update:
- the nginx compose mount
- the nginx vhost certificate paths
- `scripts/validate.sh`

---

## 3) Environment configuration contract

### 3.1 Global env file (host-only)
Operators create:
- `/etc/homelab/secrets/global.env`

This defines portable identity:
- `HOSTNAME` (e.g., geek)
- `PUBLIC_DOMAIN` (e.g., johnnyblabs.com)
- `AUTH_HOST` (e.g., auth.johnnyblabs.com)

Stacks may reference it via `env_file:`.

### 3.2 Per-stack env files (host-only)
Stacks may additionally require:
- `/etc/homelab/secrets/nginx.env`
- `/etc/homelab/secrets/authentik.env`
- `/etc/homelab/secrets/bookstack.env`

Repo includes `.env.example` equivalents in `env/examples/`.

---

## 4) Operations: single command & control interface

Top-level Makefile is the preferred UX:
- `make bootstrap` — create host dirs/perms + docker network(s)
- `make deploy-edge` — deploy nginx config to host, test, reload
- `make up STACK=stacks/10-auth/authentik` — start a stack
- `make down STACK=...` — stop a stack
- `make validate` — run safety checks & smoke tests
- `make snapshot` — backup host config + env + inventory metadata
- `make rollback REF=<git-ref>` — rollback repo desired state and redeploy edge

Any new operator workflow must be expressible via Make targets and scripts.

---

## 5) Trust boundaries (LAN vs WAN)

### WAN (public domain)
Hosts under `*.${PUBLIC_DOMAIN}` are considered WAN-capable.
Default requirement:
- must be authenticated via Authentik (forward-auth)
- Nginx is the enforcement point

### LAN (internal)
Internal-only domains (e.g. `*.geek`) may be:
- LAN-allowlisted at nginx, unauthenticated
- or still protected by Authentik if desired

Document per-app security stance in the app stack README.

---

## 6) “No magic” definition
A change is acceptable only if:
- it is reproducible from a clean host by following docs + scripts
- it does not require undocumented manual edits
- it does not embed secrets into git-tracked files

If Copilot/agent generates code, it must follow these rules.

EOF

# ------------------------------------------------------------------------------
# Public README.md (beautiful + professional)
# ------------------------------------------------------------------------------
say "== Writing README.md =="
cat > README.md <<'EOF'
# GEEK Home Platform — homelab-platform

A **production-quality, reusable homelab platform** built on a **stack-first** architecture.

**Design goals**
- Docker-first deployment
- Clean reverse proxy layer (Nginx)
- Central SSO (Authentik)
- Clear trust boundaries:
  - LAN access allowed where appropriate
  - WAN access always authenticated
- Secrets never committed to git
- Fully documented, reproducible setup for new operators

---

## Repository philosophy

This repo defines **desired state** (configs, compose files, runbooks).  
The host provides **runtime state** (secrets, certs, persistent data).

There is no hidden magic:
- Host state is created/updated via scripts in `scripts/`
- Every stack is self-contained under `stacks/`
- Backups and rollbacks are first-class operations

---

## Quickstart

### 1) Configure host-only environment
Create the global env file on the host:

```bash
sudo mkdir -p /etc/homelab/secrets
sudo nano /etc/homelab/secrets/global.env
```

Start from: `env/examples/global.env.example`

### 2) Bootstrap host contracts and network
```bash
make bootstrap
```

### 3) Deploy edge (Nginx)
```bash
make deploy-edge
make validate
```

### 4) Bring up identity (Authentik)
```bash
make up STACK=stacks/10-auth/authentik
```

### 5) Add apps (one at a time)
```bash
make up STACK=stacks/20-apps/bookstack
```

---

## Operations

- Backup runtime config + env + inventory:
  ```bash
  make snapshot
  ```
- Roll back desired state:
  ```bash
  make rollback REF=<git-tag-or-sha>
  ```

See `docs/operations.md` for full runbooks.

---

## Structure

```
stacks/                 # deployable units, ordered by prefix
  00-edge/nginx/        # ingress + nginx config deployment
  10-auth/authentik/    # SSO (Authentik)
  20-apps/bookstack/    # example application stack

scripts/                # the only place allowed to mutate host state
env/examples/           # templates only (no secrets)
docs/                   # architecture + runbooks
```

---

## Security model

- Nginx is the single edge entrypoint (80/443).
- WAN-exposed services are protected by Authentik (forward-auth).
- Secrets and certificates are stored on-host, never in git.

See `docs/security.md`.

EOF

# ------------------------------------------------------------------------------
# Docs
# ------------------------------------------------------------------------------
say "== Writing docs =="
cat > docs/architecture.md <<'EOF'
# Architecture

## Overview
The platform is composed of independent **stacks**, deployed in a controlled order:

1) **00-edge**: Nginx reverse proxy (the only service binding host ports 80/443)
2) **10-auth**: Authentik identity services (SSO)
3) **20-apps**: Applications (added one-by-one)

## Source of truth model
- Repo: desired state (compose + reference configs + docs)
- Host: runtime state (secrets, certs, persistent data)

## Goals
- Reproducibility: a new operator can deploy from scratch by following docs + scripts.
- Safety: no secrets in git; deterministic deploy/rollback/backup.
- Clarity: minimal assumptions; explicit networks; single edge.
EOF

cat > docs/networking.md <<'EOF'
# Networking

## Shared platform network (explicit)
A shared Docker network is used for service discovery and proxying:

- Network name: `geek-infra`
- Created explicitly via `make bootstrap` / `scripts/bootstrap_host.sh`

All platform services that must communicate (nginx, authentik, apps) attach to this network.

## Proxying rule
Nginx proxies to upstreams by **Docker service name** on `geek-infra`.
Do not proxy to host IPs. Do not rely on container IPs.

## Port exposure
Only the Nginx edge stack binds host ports 80/443.
All other services remain internal unless explicitly required for bootstrap/debug.
EOF

cat > docs/security.md <<'EOF'
# Security

## Trust boundaries
- **WAN**: always authenticated (Authentik forward-auth)
- **LAN**: may be allowlisted at Nginx (unauth) or also protected by Authentik

## Secrets handling
Secrets must never be committed to git.
Operator places secrets on-host, typically under:
- `/etc/homelab/secrets/`

## TLS certificates
Certificates are host-owned and mounted read-only into the Nginx container.
Supported patterns:
- `/etc/nginx-docker/certs/` (simpler)
- `/etc/ssl/homelab/<domain>/` (cleaner separation)
EOF

cat > docs/nginx.md <<'EOF'
# Nginx (Edge)

## Critical rule: minimal mounts
Do not mount the entire `/etc/nginx` into the container.
Mount only:
- `nginx.conf`
- `conf.d/` (or sites-enabled)
- `snippets/`
- `certs/` (read-only)

Mounting the full directory is known to break default Nginx files (e.g., mime.types).

## Deployment model
- Reference nginx tree lives in: `stacks/00-edge/nginx/etc-nginx-docker/`
- Runtime nginx tree lives on host: `/etc/nginx-docker/`
- Deploy script syncs repo → host, excluding cert contents.

## Validation
- `docker exec geek-nginx nginx -t`
- `curl -H 'Host: <vhost>' http://127.0.0.1`
EOF

cat > docs/authentik.md <<'EOF'
# Authentik (SSO)

## Role
Authentik provides centralized authentication and SSO for WAN services.

## Key operational requirement
Nginx must be able to reach:
- authentik server
- authentik outpost

This requires:
- Nginx container attaches to the same Docker network (`geek-infra`)
- Nginx proxies by service name (not host IP)

## Deployment order
Authentik is deployed only after Nginx is stable.

## Forward-auth
Forward-auth configuration will be applied at Nginx per-vhost.
EOF

cat > docs/operations.md <<'EOF'
# Operations

## Day 0: Bootstrap host
1) Create global env on host:
   - `/etc/homelab/secrets/global.env` (see `env/examples/global.env.example`)
2) Run:
   - `make bootstrap`

This creates required host directories, sets safe permissions, and creates the shared Docker network.

## Day 1: Deploy edge (Nginx)
- `make deploy-edge`
- `make validate`

## Backups
- `make snapshot` produces a timestamped archive under `./backups/` containing:
  - `/etc/nginx-docker` (runtime config)
  - `/etc/homelab/secrets` (envs)
  - inventory metadata (docker/compose versions, container list, networks)

## Rollbacks
Two layers exist:

### Desired-state rollback (git ref)
- `make rollback REF=<tag-or-sha>`
This checks out the ref and re-runs edge deploy + validation.

### Runtime rollback (host snapshot)
- Restore from a prior `./backups/*.tgz` archive if runtime state is corrupted.

## No hidden state
All changes to host config must flow from:
- scripts in `scripts/`
- documented operator actions in this file
EOF

# ------------------------------------------------------------------------------
# env/examples
# ------------------------------------------------------------------------------
say "== Writing env examples =="
cat > env/examples/global.env.example <<'EOF'
# Global environment (HOST-ONLY in real deployments)
# Copy to: /etc/homelab/secrets/global.env

# Host identity (portable defaults)
HOSTNAME=geek

# Public domain for WAN-capable services (bring your own)
PUBLIC_DOMAIN=johnnyblabs.com

# Common hosts (override as needed)
AUTH_HOST=auth.${PUBLIC_DOMAIN}

# Optional: internal-only base domain for LAN convenience
INTERNAL_DOMAIN=geek
EOF

cat > env/examples/nginx.env.example <<'EOF'
# Nginx stack env (HOST-ONLY in real deployments)
# Copy to: /etc/homelab/secrets/nginx.env

# Container name is used by scripts/validate.sh for nginx -t
NGINX_CONTAINER=geek-nginx

# Cert strategy (choose ONE and keep docs/validate consistent)
# Option A (simple): certs under /etc/nginx-docker/certs on host
CERT_HOST_DIR=/etc/nginx-docker/certs

# Option B (clean separation): /etc/ssl/homelab/<domain>
# CERT_HOST_DIR=/etc/ssl/homelab/johnnyblabs.com
EOF

cat > env/examples/authentik.env.example <<'EOF'
# Authentik env example (HOST-ONLY in real deployments)
# Copy to: /etc/homelab/secrets/authentik.env
#
# NOTE: Do not commit real values.

# Example placeholders:
AUTHENTIK_SECRET_KEY=REPLACE_ME
AUTHENTIK_POSTGRES_PASSWORD=REPLACE_ME
AUTHENTIK_REDIS_PASSWORD=REPLACE_ME

# Outpost token is sensitive:
AUTHENTIK_OUTPOST_TOKEN=REPLACE_ME
EOF

cat > env/examples/bookstack.env.example <<'EOF'
# BookStack env example (HOST-ONLY in real deployments)
# Copy to: /etc/homelab/secrets/bookstack.env
#
# NOTE: Do not commit real values.

BOOKSTACK_DB_PASSWORD=REPLACE_ME
BOOKSTACK_APP_URL=https://bookstack.johnnyblabs.com
EOF

# ------------------------------------------------------------------------------
# scripts/lib/common.sh
# ------------------------------------------------------------------------------
say "== Writing scripts/lib/common.sh =="
cat > scripts/lib/common.sh <<'EOF'
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
EOF
chmod +x scripts/lib/common.sh

# ------------------------------------------------------------------------------
# scripts/bootstrap_host.sh
# ------------------------------------------------------------------------------
say "== Writing scripts/bootstrap_host.sh =="
cat > scripts/bootstrap_host.sh <<'EOF'
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
EOF
chmod +x scripts/bootstrap_host.sh

# ------------------------------------------------------------------------------
# scripts/deploy_edge_nginx.sh
# ------------------------------------------------------------------------------
say "== Writing scripts/deploy_edge_nginx.sh =="
cat > scripts/deploy_edge_nginx.sh <<'EOF'
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
EOF
chmod +x scripts/deploy_edge_nginx.sh

# ------------------------------------------------------------------------------
# scripts/inventory.sh
# ------------------------------------------------------------------------------
say "== Writing scripts/inventory.sh =="
cat > scripts/inventory.sh <<'EOF'
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
EOF
chmod +x scripts/inventory.sh

# ------------------------------------------------------------------------------
# scripts/snapshot.sh
# ------------------------------------------------------------------------------
say "== Writing scripts/snapshot.sh =="
cat > scripts/snapshot.sh <<'EOF'
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
EOF
chmod +x scripts/snapshot.sh

# ------------------------------------------------------------------------------
# scripts/rollback.sh
# ------------------------------------------------------------------------------
say "== Writing scripts/rollback.sh =="
cat > scripts/rollback.sh <<'EOF'
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
EOF
chmod +x scripts/rollback.sh

# ------------------------------------------------------------------------------
# scripts/validate.sh
# ------------------------------------------------------------------------------
say "== Writing scripts/validate.sh =="
cat > scripts/validate.sh <<'EOF'
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
EOF
chmod +x scripts/validate.sh

# ------------------------------------------------------------------------------
# Makefile
# ------------------------------------------------------------------------------
say "== Writing Makefile =="
cat > Makefile <<'EOF'
SHELL := /usr/bin/env bash

.PHONY: help bootstrap deploy-edge validate snapshot rollback up down logs

help:
	@echo "homelab-platform command & control"
	@echo
	@echo "  make bootstrap"
	@echo "  make deploy-edge"
	@echo "  make validate"
	@echo "  make snapshot"
	@echo "  make rollback REF=<git-ref>"
	@echo "  make up STACK=stacks/10-auth/authentik"
	@echo "  make down STACK=stacks/10-auth/authentik"
	@echo "  make logs STACK=stacks/10-auth/authentik"

bootstrap:
	./scripts/bootstrap_host.sh

deploy-edge:
	./scripts/deploy_edge_nginx.sh

validate:
	./scripts/validate.sh

snapshot:
	./scripts/snapshot.sh

rollback:
	@if [ -z "$(REF)" ]; then echo "Usage: make rollback REF=<git-ref>"; exit 1; fi
	./scripts/rollback.sh "$(REF)"

up:
	@if [ -z "$(STACK)" ]; then echo "Usage: make up STACK=<stack-path>"; exit 1; fi
	docker compose -f "$(STACK)/docker-compose.yml" up -d

down:
	@if [ -z "$(STACK)" ]; then echo "Usage: make down STACK=<stack-path>"; exit 1; fi
	docker compose -f "$(STACK)/docker-compose.yml" down

logs:
	@if [ -z "$(STACK)" ]; then echo "Usage: make logs STACK=<stack-path>"; exit 1; fi
	docker compose -f "$(STACK)/docker-compose.yml" logs -f --tail=200
EOF

# ------------------------------------------------------------------------------
# stacks/00-edge/nginx
# ------------------------------------------------------------------------------
say "== Writing stacks/00-edge/nginx docker-compose.yml =="
cat > stacks/00-edge/nginx/docker-compose.yml <<'EOF'
name: geek

services:
  nginx:
    image: nginx:1.27-alpine
    container_name: geek-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/nginx-docker/nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/nginx-docker/conf.d:/etc/nginx/conf.d:ro
      - /etc/nginx-docker/snippets:/etc/nginx/snippets:ro
      - /etc/nginx-docker/certs:/etc/nginx/certs:ro
    networks:
      - geek-infra

networks:
  geek-infra:
    external: true
    name: geek-infra
EOF

say "== Writing stacks/00-edge/nginx reference nginx config =="
cat > stacks/00-edge/nginx/etc-nginx-docker/nginx.conf <<'EOF'
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events { worker_connections  1024; }

http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;

  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

  access_log  /var/log/nginx/access.log  main;

  sendfile        on;
  keepalive_timeout  65;

  include /etc/nginx/conf.d/*.conf;
}
EOF

cat > stacks/00-edge/nginx/etc-nginx-docker/snippets/proxy_common.conf <<'EOF'
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

map $http_upgrade $connection_upgrade { default upgrade; '' close; }
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;

proxy_read_timeout 300;
proxy_send_timeout 300;
EOF

cat > stacks/00-edge/nginx/etc-nginx-docker/snippets/lan_only.conf <<'EOF'
allow 10.0.0.0/8;
allow 172.16.0.0/12;
allow 192.168.0.0/16;
deny all;
EOF

cat > stacks/00-edge/nginx/etc-nginx-docker/snippets/authentik_forwardauth.conf <<'EOF'
# Placeholder until Authentik stack is deployed
return 503;
EOF

cat > stacks/00-edge/nginx/etc-nginx-docker/conf.d/00_geek.conf <<'EOF'
server {
  listen 80;
  server_name geek;

  location = / {
    add_header Content-Type text/plain;
    return 200 "GEEK Home Platform: nginx edge is up\n";
  }
}
EOF

cat > stacks/00-edge/nginx/etc-nginx-docker/conf.d/10_auth_stub.conf <<'EOF'
server {
  listen 80;
  server_name auth.johnnyblabs.com;

  location = / {
    add_header Content-Type text/plain;
    return 200 "auth host reserved (Authentik not deployed yet)\n";
  }
}
EOF

# ------------------------------------------------------------------------------
# stack placeholders
# ------------------------------------------------------------------------------
say "== Writing stacks/10-auth/authentik skeleton =="
cat > stacks/10-auth/authentik/.env.example <<'EOF'
# Copy to /etc/homelab/secrets/authentik.env (HOST-ONLY)
AUTHENTIK_SECRET_KEY=REPLACE_ME
AUTHENTIK_POSTGRES_PASSWORD=REPLACE_ME
AUTHENTIK_REDIS_PASSWORD=REPLACE_ME
AUTHENTIK_OUTPOST_TOKEN=REPLACE_ME
EOF

cat > stacks/10-auth/authentik/docker-compose.yml <<'EOF'
name: geek
services:
  placeholder:
    image: alpine:3.20
    command: ["sh", "-c", "echo 'Authentik stack placeholder'; sleep 3600"]
    networks: [geek-infra]
networks:
  geek-infra:
    external: true
    name: geek-infra
EOF

say "== Writing stacks/20-apps/bookstack skeleton =="
cat > stacks/20-apps/bookstack/.env.example <<'EOF'
# Copy to /etc/homelab/secrets/bookstack.env (HOST-ONLY)
BOOKSTACK_DB_PASSWORD=REPLACE_ME
BOOKSTACK_APP_URL=https://bookstack.johnnyblabs.com
EOF

cat > stacks/20-apps/bookstack/docker-compose.yml <<'EOF'
name: geek
services:
  placeholder:
    image: alpine:3.20
    command: ["sh", "-c", "echo 'BookStack stack placeholder'; sleep 3600"]
    networks: [geek-infra]
networks:
  geek-infra:
    external: true
    name: geek-infra
EOF

say "== Marking backups/ as local-only (gitignored) =="
cat > backups/.keep <<'EOF'
This directory is gitignored. It stores local snapshot archives created by scripts/snapshot.sh
EOF

say "== Done =="
echo
echo "Next steps:"
echo "  1) Review ADMIN.md"
echo "  2) sudo cp env/examples/global.env.example /etc/homelab/secrets/global.env"
echo "  3) make bootstrap"
echo "  4) docker compose -f stacks/00-edge/nginx/docker-compose.yml up -d"
echo "  5) make deploy-edge"
echo "  6) make validate"
