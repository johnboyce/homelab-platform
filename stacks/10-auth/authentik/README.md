# Authentik Stack

Identity Provider and Single Sign-On (SSO) for the homelab platform.

## Services

- `authentik-server` - Main Authentik web server (ports 9000, 9443)
- `authentik-worker` - Background task worker
- `authentik-outpost` - Forward authentication proxy

## Dependencies

- PostgreSQL (`geek-postgres`) - Database
- Redis (`geek-redis`) - Caching and sessions

## Environment Variables

Required in `/etc/homelab/secrets/authentik.env`:
- `AUTHENTIK_SECRET_KEY` - Application secret key
- `AUTHENTIK_POSTGRESQL__PASSWORD` - Database password
- `AUTHENTIK_REDIS__PASSWORD` - Redis password (must match redis.env)
- `AUTHENTIK_TOKEN` - Outpost authentication token

## Accessing

- Web UI: https://auth.johnnyblabs.com (via nginx proxy)
- Direct: http://localhost:9000

## Initial Setup

1. Access the web UI
2. Complete initial setup wizard
3. Create admin account
4. Configure applications and outposts

See `docs/authentik.md` for more details.
