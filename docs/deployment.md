# Deployment Guide

Complete step-by-step guide for deploying the homelab platform from scratch.

## Prerequisites

- Ubuntu/Debian Linux server
- Docker and Docker Compose installed
- Root/sudo access
- Domain name configured (optional for WAN access)

## 1. Initial Setup

### Clone the repository
```bash
cd ~
git clone https://github.com/johnboyce/homelab-platform.git
cd homelab-platform
```

### Bootstrap the host
```bash
make bootstrap
```

This creates:
- `/etc/homelab/secrets/` - Directory for environment files
- `/etc/nginx-docker/` - Directory for Nginx configuration
- `geek-infra` - Docker network for all services

## 2. Configure Environment Files

### Global configuration
```bash
sudo cp env/examples/global.env.example /etc/homelab/secrets/global.env
sudo nano /etc/homelab/secrets/global.env
```

Update:
- `HOSTNAME` - Your server hostname
- `PUBLIC_DOMAIN` - Your domain (e.g., johnnyblabs.com)

### PostgreSQL
```bash
sudo cp env/examples/postgres.env.example /etc/homelab/secrets/postgres.env
sudo nano /etc/homelab/secrets/postgres.env
```

Set a strong `POSTGRES_PASSWORD`.

### Redis
```bash
sudo cp env/examples/redis.env.example /etc/homelab/secrets/redis.env
sudo nano /etc/homelab/secrets/redis.env
```

Set a strong `REDIS_PASSWORD`.

### Authentik
```bash
sudo cp env/examples/authentik.env.example /etc/homelab/secrets/authentik.env
sudo nano /etc/homelab/secrets/authentik.env
```

Generate and set:
- `AUTHENTIK_SECRET_KEY` - Run: `openssl rand -base64 64`
- `AUTHENTIK_POSTGRESQL__PASSWORD` - Strong password for database
- `AUTHENTIK_REDIS__PASSWORD` - Must match `REDIS_PASSWORD` above
- `AUTHENTIK_TOKEN` - Generate after Authentik is running

### Bookstack
```bash
sudo cp env/examples/bookstack.env.example /etc/homelab/secrets/bookstack.env
sudo nano /etc/homelab/secrets/bookstack.env
```

Set:
- `BOOKSTACK_DB_PASSWORD` - Strong password
- `BOOKSTACK_APP_URL` - Public URL (e.g., https://bookstack.johnnyblabs.com)

### Pi-hole
```bash
sudo cp env/examples/pihole.env.example /etc/homelab/secrets/pihole.env
sudo nano /etc/homelab/secrets/pihole.env
```

Set:
- `PIHOLE_WEB_PASSWORD` - Admin password
- `PIHOLE_HOST_IP` - Server IP address

### Cockpit (optional)
```bash
sudo cp env/examples/cockpit.env.example /etc/homelab/secrets/cockpit.env
```

No required changes unless customizing.

## 3. Deploy Services

### Option A: Deploy Everything at Once
```bash
make deploy-all
```

### Option B: Deploy Layer by Layer (Recommended)

#### 3.1 Deploy Infrastructure
```bash
make deploy-infra
```

Wait for services to be healthy:
```bash
docker ps | grep geek-postgres
docker ps | grep geek-redis
```

#### 3.2 Create Application Databases

Create Authentik database:
```bash
docker exec -it geek-postgres psql -U postgres <<EOF
CREATE DATABASE authentik;
CREATE USER authentik WITH PASSWORD 'your-authentik-db-password';
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;
\c authentik
GRANT ALL ON SCHEMA public TO authentik;
EOF
```

Create Bookstack database:
```bash
docker exec -it geek-postgres psql -U postgres <<EOF
CREATE DATABASE bookstack;
CREATE USER bookstack WITH PASSWORD 'your-bookstack-db-password';
GRANT ALL PRIVILEGES ON DATABASE bookstack TO bookstack;
\c bookstack
GRANT ALL ON SCHEMA public TO bookstack;
EOF
```

#### 3.3 Deploy Nginx (Edge)
```bash
make deploy-edge
```

#### 3.4 Deploy Authentik
```bash
make deploy-auth
```

Wait for Authentik to initialize (first run takes a few minutes):
```bash
docker logs -f authentik-server
```

Access Authentik at `http://localhost:9000` and complete initial setup.

Generate the outpost token:
1. Log into Authentik web UI
2. Go to Applications > Outposts
3. Create or edit outpost
4. Copy the token
5. Add it to `/etc/homelab/secrets/authentik.env` as `AUTHENTIK_TOKEN`
6. Restart Authentik: `make deploy-auth`

#### 3.5 Deploy Applications
```bash
make deploy-apps
```

This deploys:
- Pi-hole (DNS/ad-blocking)
- Bookstack (wiki/docs)
- Cockpit (system admin)

## 4. Verify Deployment

Check all services are running:
```bash
make status
```

Expected output should show all containers in "Up" status.

## 5. Initial Configuration

### Authentik
1. Access: `http://localhost:9000` or `https://auth.yourdom ain.com`
2. Create admin account (if not done during initial setup)
3. Configure applications and providers
4. Set up forward authentication for other services

### Bookstack
1. Access: `https://bookstack.yourdomain.com`
2. Login with default: `admin@admin.com` / `password`
3. Change admin password immediately
4. Configure settings and (optionally) Authentik SSO

### Pi-hole
1. Access: Via nginx proxy or directly on network
2. Configure DNS settings on your router/devices
3. Add blocklists and custom DNS entries
4. Test ad-blocking

### Cockpit
1. Access: `https://cockpit.yourdomain.com` or `http://localhost:9090`
2. Login with system user credentials
3. Explore system monitoring and management features

## 6. Configure Nginx Proxy

Add proxy configurations for each service in `/etc/nginx-docker/conf.d/`:

Example for Bookstack (`bookstack.conf`):
```nginx
server {
    listen 80;
    server_name bookstack.yourdomain.com;
    
    location / {
        proxy_pass http://geek-bookstack:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Reload Nginx:
```bash
docker exec geek-nginx nginx -s reload
```

## 7. Set Up TLS Certificates

1. Obtain certificates (Let's Encrypt, etc.)
2. Place in `/etc/nginx-docker/certs/`
3. Update Nginx configurations to use HTTPS
4. Reload Nginx

See `docs/nginx.md` for details.

## 8. Backup

Create initial backup:
```bash
make snapshot
```

Set up automated backups (cron, etc.) - see `docs/operations.md`.

## Troubleshooting

### Service won't start
```bash
# Check logs
docker logs <container-name>

# Check env files exist
ls -la /etc/homelab/secrets/

# Verify network
docker network inspect geek-infra
```

### Database connection errors
```bash
# Check PostgreSQL
docker exec geek-postgres psql -U postgres -l

# Test database connection
docker exec -it geek-postgres psql -U authentik -d authentik
```

### Redis connection errors
```bash
# Test Redis
docker exec geek-redis redis-cli -a <password> ping
```

### Can't access services
- Check Docker networking: `docker network inspect geek-infra`
- Verify containers are on the correct network
- Check Nginx proxy configuration
- Review firewall rules

## Maintenance

### Update a service
```bash
# Pull latest image
docker pull <image>

# Restart the stack
make down STACK=stacks/path/to/stack
make up STACK=stacks/path/to/stack
```

### View logs
```bash
make logs STACK=stacks/path/to/stack
```

### Database maintenance
See `docs/postgresql.md` for backup, restore, and maintenance procedures.

## Security Checklist

- [ ] Strong passwords for all services
- [ ] TLS certificates installed
- [ ] Authentik SSO configured for WAN-exposed services
- [ ] Firewall rules configured
- [ ] Regular backups automated
- [ ] Log monitoring set up
- [ ] Secrets never committed to git

## Next Steps

- Configure additional applications
- Set up monitoring and alerting
- Implement automated backups
- Configure Authentik SSO for all services
- Document your specific customizations

For more information, see:
- `docs/architecture.md` - Platform architecture
- `docs/operations.md` - Operational procedures
- `docs/migration.md` - Migrating from existing installations
- `docs/postgresql.md` - Database management
