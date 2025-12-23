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

The platform supports both Docker named volumes and bind mounts for data persistence:

**Named Volumes (Preferred for new services)**:
- Docker-managed named volumes for persistent data
- Naming convention: `geek-{service}-{purpose}` (e.g., `geek-redis-data`, `geek-authentik-media`)
- Benefits: Portable, consistent, easy to manage with Docker commands
- Managed by Docker: `docker volume ls`, `docker volume inspect`, etc.

**Bind Mounts (Acceptable for existing data)**:
- Direct host path mounts (e.g., `/srv/homelab/postgres/pgdata`)
- Use when migrating existing services with data in specific locations
- Provides explicit control over data location on the host filesystem
- PostgreSQL uses `/srv/homelab/postgres/pgdata` for its data directory

**Configuration Files**:
- Nginx uses bind mounts for configuration files (`/etc/nginx-docker/*`)
- These are read-only (`:ro`) mounts for host-managed configuration

**Examples**:
- PostgreSQL: `/srv/homelab/postgres/pgdata` (bind mount - existing data)
- Redis: `geek-redis-data` (named volume)
- Authentik: `geek-authentik-media`, `geek-authentik-certs` (named volumes)
- Bookstack: `geek-bookstack-config` (named volume)
- Pi-hole: `geek-pihole-etc`, `geek-pihole-dnsmasq` (named volumes)

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
