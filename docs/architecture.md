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

## Host-level vs Platform services
The platform distinguishes between:

**Platform services** (containerized, proxied via Nginx):
- Deployed as Docker containers on the `geek-infra` network
- Accessed through Nginx reverse proxy
- Examples: Authentik, Bookstack, other containerized apps

**Host-level services** (accessed directly):
- Run on the host, outside of Docker
- Accessed directly on their native ports (LAN-only)
- Examples: CasaOS (port 8888)
- Not proxied through platform Nginx to maintain clean architecture

See `docs/casaos.md` for details on host-level service access patterns.
