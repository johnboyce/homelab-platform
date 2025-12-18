# Migration Guide

This guide helps you migrate existing services (Authentik, Bookstack, Pi-hole) from their current installations into the homelab-platform repository structure.

## Prerequisites

Before migrating, ensure you have:
1. Backups of all existing service data
2. Access to current service configuration and secrets
3. The homelab-platform repository cloned and bootstrapped

## Migration Overview

The migration process involves:
1. Exporting data from existing services
2. Stopping current containers
3. Deploying services using homelab-platform
4. Importing data into new containers

## 1. Migrate PostgreSQL and Redis (Shared Infrastructure)

### Current State
- PostgreSQL running from: `/home/johnb/geek-infra/postgres`
- Redis running from: `/home/johnb/geek-infra/redis`

### Migration Steps

1. **Export PostgreSQL data:**
   ```bash
   # Backup all databases
   docker exec geek-postgres pg_dumpall -U postgres > /tmp/postgres_backup.sql
   ```

2. **Note Redis password:**
   ```bash
   # Get current Redis password from existing config
   cat /home/johnb/geek-infra/redis/.env
   ```

3. **Create env files in homelab-platform:**
   ```bash
   sudo nano /etc/homelab/secrets/postgres.env
   # Add: POSTGRES_PASSWORD=<your-password>
   
   sudo nano /etc/homelab/secrets/redis.env
   # Add: REDIS_PASSWORD=<your-password>
   ```

4. **Deploy new infrastructure:**
   ```bash
   make deploy-infra
   ```

5. **Restore PostgreSQL data:**
   ```bash
   docker exec -i geek-postgres psql -U postgres < /tmp/postgres_backup.sql
   ```

## 2. Migrate Authentik

### Current State
- Running from: `/home/johnb/geek-infra/authentik`
- Services: authentik-server, authentik-worker, authentik-outpost

### Migration Steps

1. **Export Authentik configuration:**
   ```bash
   # Get environment variables
   cat /home/johnb/geek-infra/authentik/.env > /tmp/authentik.env
   ```

2. **Create Authentik env file:**
   ```bash
   sudo nano /etc/homelab/secrets/authentik.env
   # Copy values from /tmp/authentik.env, mapping to new variable names:
   # AUTHENTIK_SECRET_KEY
   # AUTHENTIK_POSTGRESQL__PASSWORD
   # AUTHENTIK_REDIS__PASSWORD (must match redis.env)
   # AUTHENTIK_TOKEN (for outpost)
   ```

3. **Stop old Authentik containers:**
   ```bash
   cd /home/johnb/geek-infra/authentik
   docker compose down
   ```

4. **Deploy new Authentik:**
   ```bash
   cd /home/runner/work/homelab-platform/homelab-platform
   make deploy-auth
   ```

5. **Verify Authentik is running:**
   ```bash
   make status
   docker logs authentik-server
   ```

## 3. Migrate Bookstack

### Current State
- Running from CasaOS: `/var/lib/casaos/apps/big-bear-bookstack`
- Using MariaDB database: `big-bear-bookstack-db`

### Migration Steps

1. **Export Bookstack database:**
   ```bash
   docker exec big-bear-bookstack-db mysqldump -u bookstack -p bookstack > /tmp/bookstack.sql
   ```

2. **Create PostgreSQL database for Bookstack:**
   ```bash
   docker exec -i geek-postgres psql -U postgres <<EOF
   CREATE DATABASE bookstack;
   CREATE USER bookstack WITH PASSWORD 'your-password';
   GRANT ALL PRIVILEGES ON DATABASE bookstack TO bookstack;
   \c bookstack
   GRANT ALL ON SCHEMA public TO bookstack;
   EOF
   ```

3. **Convert MySQL dump to PostgreSQL (if needed):**
   Note: Bookstack may need to be reinstalled fresh on PostgreSQL, or you can use a migration tool.
   
   For a fresh install:
   ```bash
   sudo nano /etc/homelab/secrets/bookstack.env
   # Add:
   # BOOKSTACK_DB_PASSWORD=your-password
   # BOOKSTACK_APP_URL=https://bookstack.johnnyblabs.com
   ```

4. **Stop old Bookstack:**
   ```bash
   cd /var/lib/casaos/apps/big-bear-bookstack
   docker compose down
   ```

5. **Deploy new Bookstack:**
   ```bash
   cd /home/runner/work/homelab-platform/homelab-platform
   docker compose -f stacks/20-apps/bookstack/docker-compose.yml up -d
   ```

## 4. Migrate Pi-hole

### Current State
- Running as standalone container (no docker-compose labels)

### Migration Steps

1. **Export Pi-hole configuration:**
   ```bash
   docker exec pihole pihole -a -t /etc/pihole/teleporter_backup.tar.gz
   docker cp pihole:/etc/pihole/teleporter_backup.tar.gz /tmp/
   ```

2. **Get Pi-hole password:**
   ```bash
   docker exec pihole pihole -a -p
   # Note the password
   ```

3. **Create Pi-hole env file:**
   ```bash
   sudo nano /etc/homelab/secrets/pihole.env
   # Add:
   # PIHOLE_WEB_PASSWORD=your-password
   # PIHOLE_HOST_IP=your-host-ip
   ```

4. **Stop old Pi-hole:**
   ```bash
   docker stop pihole
   docker rm pihole
   ```

5. **Deploy new Pi-hole:**
   ```bash
   cd /home/runner/work/homelab-platform/homelab-platform
   docker compose -f stacks/15-network/pihole/docker-compose.yml up -d
   ```

6. **Restore Pi-hole configuration:**
   ```bash
   docker cp /tmp/teleporter_backup.tar.gz geek-pihole:/tmp/
   # Then restore via Pi-hole web interface or CLI
   ```

## 5. Deploy Cockpit (New Service)

Cockpit is a new service being added to the platform.

1. **Create Cockpit env file (optional):**
   ```bash
   sudo cp env/examples/cockpit.env.example /etc/homelab/secrets/cockpit.env
   ```

2. **Deploy Cockpit:**
   ```bash
   docker compose -f stacks/30-admin/cockpit/docker-compose.yml up -d
   ```

3. **Access Cockpit:**
   - URL: `https://cockpit.johnnyblabs.com` (via nginx proxy)
   - Or: `http://your-host-ip:9090` (direct access)
   - Login with system user credentials

## Post-Migration

1. **Verify all services are running:**
   ```bash
   make status
   ```

2. **Update Nginx configuration** to proxy to new service names:
   - `geek-postgres` instead of old postgres container
   - `geek-redis` instead of old redis container
   - `authentik-server` for Authentik
   - `geek-bookstack` for Bookstack
   - `geek-pihole` for Pi-hole
   - `geek-cockpit` for Cockpit

3. **Test each service:**
   - Authentik: `https://auth.johnnyblabs.com`
   - Bookstack: `https://bookstack.johnnyblabs.com`
   - Pi-hole: `http://pi.hole/admin`
   - Cockpit: `https://cockpit.johnnyblabs.com`

4. **Remove old containers and volumes** (after confirming everything works):
   ```bash
   # Clean up old Authentik
   cd /home/johnb/geek-infra/authentik
   docker compose down -v
   
   # Clean up old infrastructure (be careful!)
   # Only do this after confirming new infrastructure is working
   cd /home/johnb/geek-infra/postgres
   docker compose down  # Don't use -v if you want to keep data
   
   cd /home/johnb/geek-infra/redis
   docker compose down
   ```

## Troubleshooting

### Service won't start
- Check logs: `docker logs <container-name>`
- Verify env files exist: `ls -la /etc/homelab/secrets/`
- Check network: `docker network inspect geek-infra`

### Database connection errors
- Verify PostgreSQL is running: `docker ps | grep postgres`
- Check database exists: `docker exec geek-postgres psql -U postgres -l`
- Verify credentials in env files

### Redis connection errors
- Verify Redis is running: `docker ps | grep redis`
- Test connection: `docker exec geek-redis redis-cli -a <password> ping`

## Rollback

If you need to rollback to old installations:

1. Stop new containers:
   ```bash
   docker compose -f stacks/10-auth/authentik/docker-compose.yml down
   docker compose -f stacks/20-apps/bookstack/docker-compose.yml down
   # etc.
   ```

2. Start old containers:
   ```bash
   cd /home/johnb/geek-infra/authentik
   docker compose up -d
   # etc.
   ```
