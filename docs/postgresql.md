# PostgreSQL Database Management

This guide covers managing the shared PostgreSQL database used by multiple services in the homelab platform.

## Overview

The platform uses a single PostgreSQL 16 instance (`geek-postgres`) that hosts databases for multiple applications:
- **authentik**: Identity and SSO database
- **bookstack**: Wiki/documentation database
- (Future services can also use this shared instance)

## Data Storage

PostgreSQL data is stored in a **Docker named volume** (`geek-postgres-data`), consistent with all other services in the platform. This approach provides:
- **Portability**: Volumes are managed by Docker and work across different systems
- **Consistency**: All platform services use named volumes for data persistence
- **Easier management**: Use standard Docker volume commands for backup, inspection, and migration

To inspect the volume:
```bash
docker volume inspect geek-postgres-data
```

## Accessing PostgreSQL

### Using psql in the container
```bash
# Connect as postgres superuser
docker exec -it geek-postgres psql -U postgres

# Connect to a specific database
docker exec -it geek-postgres psql -U postgres -d authentik
```

### Using a database client
- Host: `localhost` (or your server IP)
- Port: `5432` (not exposed by default; expose in docker-compose if needed)
- User: `postgres`
- Password: From `/etc/homelab/secrets/postgres.env`

## Database Setup for New Applications

When adding a new application that needs a database:

1. **Create the database and user:**
   ```bash
   docker exec -it geek-postgres psql -U postgres <<EOF
   CREATE DATABASE myapp;
   CREATE USER myapp WITH PASSWORD 'secure-password';
   GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp;
   \c myapp
   GRANT ALL ON SCHEMA public TO myapp;
   EOF
   ```

2. **Update the application's env file:**
   ```bash
   sudo nano /etc/homelab/secrets/myapp.env
   # Add:
   # MYAPP_DB_HOST=geek-postgres
   # MYAPP_DB_PORT=5432
   # MYAPP_DB_NAME=myapp
   # MYAPP_DB_USER=myapp
   # MYAPP_DB_PASSWORD=secure-password
   ```

3. **Configure the application to use these credentials** in its docker-compose.yml

## Backup and Restore

### Full Backup (All Databases)
```bash
# Backup all databases
docker exec geek-postgres pg_dumpall -U postgres > /tmp/postgres_backup_$(date +%Y%m%d_%H%M%S).sql

# Or use the snapshot script
make snapshot
```

### Single Database Backup
```bash
# Backup a specific database
docker exec geek-postgres pg_dump -U postgres -d authentik > /tmp/authentik_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore from Backup
```bash
# Restore all databases
docker exec -i geek-postgres psql -U postgres < /tmp/postgres_backup.sql

# Restore a specific database
docker exec -i geek-postgres psql -U postgres -d authentik < /tmp/authentik_backup.sql
```

## Database Maintenance

### List all databases
```bash
docker exec geek-postgres psql -U postgres -c "\l"
```

### List all users
```bash
docker exec geek-postgres psql -U postgres -c "\du"
```

### Check database sizes
```bash
docker exec geek-postgres psql -U postgres -c "
SELECT 
    datname AS database,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
"
```

### Vacuum and analyze
```bash
# Vacuum all databases
docker exec geek-postgres vacuumdb -U postgres -a -z

# Vacuum a specific database
docker exec geek-postgres vacuumdb -U postgres -d authentik -z
```

## Monitoring

### Check PostgreSQL status
```bash
# Check if PostgreSQL is running
docker ps | grep geek-postgres

# Check PostgreSQL logs
docker logs geek-postgres --tail 100

# Check active connections
docker exec geek-postgres psql -U postgres -c "
SELECT datname, count(*) 
FROM pg_stat_activity 
GROUP BY datname;
"
```

### Check replication lag (if applicable)
```bash
docker exec geek-postgres psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

## Troubleshooting

### Connection refused
- Verify PostgreSQL is running: `docker ps | grep postgres`
- Check logs: `docker logs geek-postgres`
- Verify network: `docker network inspect geek-infra`

### Authentication failed
- Check password in env file: `sudo cat /etc/homelab/secrets/postgres.env`
- Verify user exists: `docker exec geek-postgres psql -U postgres -c "\du"`

### Database doesn't exist
- List databases: `docker exec geek-postgres psql -U postgres -c "\l"`
- Create if missing (see "Database Setup" above)

### Out of disk space
- Check database sizes (see "Database Maintenance" above)
- Check Docker volume: `docker volume inspect geek-postgres-data`
- Consider cleaning up old data or expanding storage

## Migration from MySQL/MariaDB

If migrating an application from MySQL/MariaDB to PostgreSQL:

1. **Export from MySQL:**
   ```bash
   docker exec mysql-container mysqldump -u user -p database > mysql_dump.sql
   ```

2. **Convert to PostgreSQL format:**
   - Use tools like `pgloader` or manual conversion
   - Handle differences in SQL syntax, data types, etc.

3. **Import to PostgreSQL:**
   ```bash
   docker exec -i geek-postgres psql -U postgres -d database < postgres_dump.sql
   ```

## Security Best Practices

1. **Use strong passwords** for all database users
2. **Don't expose port 5432** to the host unless necessary
3. **Use separate database users** for each application (not the postgres superuser)
4. **Grant minimal permissions** - only what each application needs
5. **Regular backups** - automate with cron or similar
6. **Monitor logs** for unauthorized access attempts

## Performance Tuning

For production use, consider tuning PostgreSQL settings in docker-compose:

```yaml
services:
  postgres:
    environment:
      - POSTGRES_INITDB_ARGS=-c shared_buffers=256MB -c max_connections=200
    command:
      - "postgres"
      - "-c"
      - "max_connections=200"
      - "-c"
      - "shared_buffers=256MB"
```

Adjust based on your server resources and workload.
