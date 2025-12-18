# Architecture

## Overview
The platform is composed of independent **stacks**, deployed in a controlled order:

1) **00-edge**: Nginx reverse proxy (the only service binding host ports 80/443)
2) **05-infra**: Shared infrastructure (PostgreSQL, Redis)
3) **10-auth**: Authentik identity services (SSO)
4) **15-network**: Network services (Pi-hole DNS/ad-blocking)
5) **20-apps**: Applications (Bookstack, etc.)
6) **30-admin**: Administration tools (Cockpit)

## Source of truth model
- Repo: desired state (compose + reference configs + docs)
- Host: runtime state (secrets, certs, persistent data)

## Data Persistence Strategy

All platform services use **Docker named volumes** for data persistence, following these principles:

**Named Volumes (Standard)**:
- All services use Docker-managed named volumes for persistent data
- Naming convention: `geek-{service}-{purpose}` (e.g., `geek-postgres-data`, `geek-redis-data`)
- Benefits: Portable, consistent, easy to manage with Docker commands
- Managed by Docker: `docker volume ls`, `docker volume inspect`, etc.

**Configuration Files**:
- Nginx uses bind mounts for configuration files (`/etc/nginx-docker/*`)
- These are read-only (`:ro`) mounts for host-managed configuration
- This is a special case for the edge proxy and acceptable

**No Bind Mounts for Data**:
- Bind mounts (e.g., `/srv/homelab/...`) are NOT used for persistent application data
- Maintains consistency and portability across different host systems
- Avoids hardcoded paths and permission issues

**Examples**:
- PostgreSQL: `geek-postgres-data`
- Redis: `geek-redis-data`
- Authentik: `geek-authentik-media`, `geek-authentik-certs`
- Bookstack: `geek-bookstack-config`
- Pi-hole: `geek-pihole-etc`, `geek-pihole-dnsmasq`

See individual service documentation for volume management details.

## Goals
- Reproducibility: a new operator can deploy from scratch by following docs + scripts.
- Safety: no secrets in git; deterministic deploy/rollback/backup.
- Clarity: minimal assumptions; explicit networks; single edge.

## Shared Infrastructure

The platform uses shared infrastructure services to avoid duplication:

**PostgreSQL** (`geek-postgres`):
- Single PostgreSQL 16 instance
- Hosts databases for: Authentik, Bookstack, and future apps
- Managed through standard PostgreSQL tools
- See `docs/postgresql.md` for database management

**Redis** (`geek-redis`):
- Used by Authentik for caching and sessions
- Can be used by other applications as needed

## Service Dependencies

```
┌─────────────────────────────────────────┐
│  Nginx (00-edge)                        │  ← External traffic entry point
└─────────────────────────────────────────┘
           │
           ├──→ Authentik (10-auth) ──────┐
           ├──→ Bookstack (20-apps) ──────┤
           ├──→ Cockpit (30-admin) ───────┤
           └──→ Pi-hole (15-network)      │
                                           │
           ┌───────────────────────────────┘
           │
           ↓
┌──────────────────────┐  ┌──────────────┐
│  PostgreSQL          │  │  Redis       │
│  (05-infra)          │  │  (05-infra)  │
└──────────────────────┘  └──────────────┘
```

## Host-level vs Platform services
The platform distinguishes between:

**Platform services** (containerized, proxied via Nginx):
- Deployed as Docker containers on the `geek-infra` network
- Accessed through Nginx reverse proxy
- Examples: Authentik, Bookstack, Cockpit

**Host-level services** (accessed directly):
- Run on the host, outside of Docker
- Accessed directly on their native ports (LAN-only)
- Examples: CasaOS (port 8888)
- Not proxied through platform Nginx to maintain clean architecture

See `docs/casaos.md` for details on host-level service access patterns.
