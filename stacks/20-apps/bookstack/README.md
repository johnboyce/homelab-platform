# BookStack Stack

Self-hosted wiki and documentation platform.

## Functionality

- Wiki-style documentation
- Book/Chapter/Page organization
- Search, user management, permissions
- Optional SSO integration with Authentik

## Dependencies

- PostgreSQL (`geek-postgres`) - Database

## Environment Variables

Required in `/etc/homelab/secrets/bookstack.env`:
- `BOOKSTACK_DB_PASSWORD` - Database password
- `BOOKSTACK_APP_URL` - Public URL for the application

Optional (for Authentik SSO):
- `BOOKSTACK_AUTH_METHOD`
- `BOOKSTACK_OIDC_*` variables

## Accessing

- Web UI: https://bookstack.johnnyblabs.com (via nginx proxy)

## Migration from MariaDB

If migrating from a MariaDB installation:
1. Export data from MariaDB
2. Convert to PostgreSQL format
3. Import into PostgreSQL database

See `docs/migration.md` for detailed steps.

## Initial Setup

1. Access the web UI
2. Default credentials: admin@admin.com / password
3. Change admin password immediately
4. Configure application settings
