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

