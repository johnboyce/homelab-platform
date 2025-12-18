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

### 3) Deploy shared infrastructure (PostgreSQL, Redis)
```bash
make deploy-infra
```

### 4) Deploy edge (Nginx)
```bash
make deploy-edge
make validate
```

### 5) Bring up identity (Authentik)
```bash
make deploy-auth
```

### 6) Deploy applications
```bash
make deploy-apps
```

Or deploy everything at once:
```bash
make deploy-all
```

---

## Host-level Services

Some services run on the host (outside Docker) and are accessed directly:
- **CasaOS**: Home management dashboard, accessible at `http://<host-ip>:8888` (LAN-only)

See `docs/casaos.md` for details on host-level service access and security.

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
  05-infra/             # shared infrastructure
    postgres/           # PostgreSQL database (shared by all apps)
    redis/              # Redis cache (used by Authentik)
  10-auth/authentik/    # SSO (Authentik)
  15-network/pihole/    # DNS and ad-blocking
  20-apps/bookstack/    # wiki/documentation application
  30-admin/cockpit/     # system administration dashboard

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

