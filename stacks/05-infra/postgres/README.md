# PostgreSQL Stack

Shared PostgreSQL 16 database instance for all platform applications.

## Databases Hosted

- `authentik` - Authentik identity and SSO
- `bookstack` - BookStack wiki/documentation
- (Additional databases can be created as needed)

## Environment Variables

Required in `/etc/homelab/secrets/postgres.env`:
- `POSTGRES_PASSWORD` - Superuser password

## Management

See `docs/postgresql.md` for database management commands.

## Accessing

```bash
# Interactive psql
docker exec -it geek-postgres psql -U postgres

# List databases
docker exec geek-postgres psql -U postgres -c "\l"
```
