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
