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

