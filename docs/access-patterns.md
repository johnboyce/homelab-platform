# Access Patterns: LAN vs WAN

This document explains how services are accessed from the LAN (local network) versus WAN (internet), and how to configure each pattern.

## Overview

The platform supports two primary access patterns:

1. **LAN Access**: Internal network access using local hostnames (e.g., `geek`, `bookstack.geek`)
2. **WAN Access**: Internet access using public domain (e.g., `bookstack.johnnyblabs.com`)

## Design Principles

- **LAN access**: Trusted network, direct access without mandatory authentication
- **WAN access**: Untrusted network, requires authentication via Authentik (forward-auth)
- **Single edge**: Nginx reverse proxy handles both LAN and WAN traffic
- **DNS-based routing**: Different DNS responses for LAN vs WAN

## LAN Access Pattern

### How it works
1. Client uses local DNS (Pi-hole or router DNS)
2. DNS resolves `bookstack.geek` → `192.168.1.x` (LAN IP)
3. Client connects to Nginx on port 80/443
4. Nginx proxies to `geek-bookstack` container on `geek-infra` network
5. No authentication required (trusted network)

### Configuration

#### DNS Setup (Pi-hole)
Add local DNS entries in Pi-hole:
```
192.168.1.100  geek
192.168.1.100  bookstack.geek
192.168.1.100  auth.geek
192.168.1.100  pihole.geek
192.168.1.100  cockpit.geek
```

Or use wildcard: `*.geek → 192.168.1.100`

#### Nginx Configuration Example
`/etc/nginx-docker/conf.d/bookstack-lan.conf`:
```nginx
# LAN access - no authentication required
server {
    listen 80;
    server_name bookstack.geek;
    
    location / {
        proxy_pass http://geek-bookstack:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Optional: HTTPS for LAN (requires self-signed or internal CA cert)
server {
    listen 443 ssl;
    server_name bookstack.geek;
    
    ssl_certificate /etc/nginx/certs/geek.crt;
    ssl_certificate_key /etc/nginx/certs/geek.key;
    
    location / {
        proxy_pass http://geek-bookstack:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

## WAN Access Pattern

### How it works
1. Client uses public DNS
2. DNS resolves `bookstack.johnnyblabs.com` → Public IP
3. Port forwarding routes 80/443 → LAN IP:80/443
4. Nginx checks Authentik for authentication
5. If authenticated, proxies to `geek-bookstack`
6. If not authenticated, redirects to Authentik login

### Configuration

#### DNS Setup (Public DNS)
In your domain registrar or DNS provider:
```
A     bookstack.johnnyblabs.com  →  YOUR_PUBLIC_IP
A     auth.johnnyblabs.com       →  YOUR_PUBLIC_IP
A     cockpit.johnnyblabs.com    →  YOUR_PUBLIC_IP
CNAME *.johnnyblabs.com          →  johnnyblabs.com (optional wildcard)
```

#### Port Forwarding (Router)
```
External 80  → Internal 192.168.1.100:80
External 443 → Internal 192.168.1.100:443
```

#### Nginx Configuration Example
`/etc/nginx-docker/conf.d/bookstack-wan.conf`:
```nginx
# WAN access - requires Authentik authentication
server {
    listen 80;
    server_name bookstack.johnnyblabs.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name bookstack.johnnyblabs.com;
    
    # TLS configuration
    ssl_certificate /etc/nginx/certs/johnnyblabs.com.crt;
    ssl_certificate_key /etc/nginx/certs/johnnyblabs.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Authentik forward-auth configuration
    include /etc/nginx/snippets/authentik-proxy.conf;
    
    location / {
        # Authenticate via Authentik outpost
        auth_request /outpost.goauthentik.io/auth/nginx;
        error_page 401 = @goauthentik_proxy_signin;
        
        # Pass authentication headers
        auth_request_set $auth_user $upstream_http_x_authentik_username;
        auth_request_set $auth_email $upstream_http_x_authentik_email;
        proxy_set_header X-authentik-username $auth_user;
        proxy_set_header X-authentik-email $auth_email;
        
        # Proxy to application
        proxy_pass http://geek-bookstack:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    # Authentik authentication endpoints
    location /outpost.goauthentik.io {
        proxy_pass http://authentik-outpost:9300/outpost.goauthentik.io;
        proxy_set_header Host $host;
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # Authentik sign-in redirect
    location @goauthentik_proxy_signin {
        internal;
        add_header Set-Cookie $auth_cookie;
        return 302 /outpost.goauthentik.io/start?rd=$request_uri;
    }
}
```

#### Authentik Snippet
Create `/etc/nginx-docker/snippets/authentik-proxy.conf`:
```nginx
# Authentik proxy configuration snippet
# Include this in server blocks that require authentication

# Increase buffer sizes for auth headers
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;

# Preserve original request information
set $original_uri $request_uri;
set $original_host $http_host;
```

## Hybrid Access (Both LAN and WAN)

You can configure Nginx to serve both patterns simultaneously:

```nginx
# Serve both LAN and WAN
server {
    listen 80;
    listen 443 ssl;
    server_name bookstack.geek bookstack.johnnyblabs.com;
    
    # TLS configuration (for HTTPS)
    ssl_certificate /etc/nginx/certs/bookstack.crt;
    ssl_certificate_key /etc/nginx/certs/bookstack.key;
    
    # Conditional authentication based on server name
    set $auth_required 0;
    if ($server_name ~* "johnnyblabs.com$") {
        set $auth_required 1;
    }
    
    location / {
        # Only require auth for WAN access
        if ($auth_required = 1) {
            auth_request /outpost.goauthentik.io/auth/nginx;
            error_page 401 = @goauthentik_proxy_signin;
        }
        
        proxy_pass http://geek-bookstack:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Authentik endpoints (only for WAN)
    location /outpost.goauthentik.io {
        proxy_pass http://authentik-outpost:9300/outpost.goauthentik.io;
        # ... (same as above)
    }
    
    location @goauthentik_proxy_signin {
        internal;
        return 302 /outpost.goauthentik.io/start?rd=$request_uri;
    }
}
```

## Service-Specific Access Recommendations

### Public Services (WAN + LAN)
- **Bookstack**: Both LAN and WAN with authentication on WAN
- **Authentik**: Both (needs to be accessible for WAN auth)

### LAN-Only Services
- **Pi-hole**: LAN only (DNS management is internal)
- **Cockpit**: LAN only (system administration)
- **PostgreSQL**: Never exposed (internal docker network only)
- **Redis**: Never exposed (internal docker network only)

### Optional WAN Services
- **Cockpit**: Could expose with strong authentication, but risky

## Deployment Order Recommendations

### For LAN-First Setup (Recommended)
1. Deploy infrastructure (postgres, redis)
2. Deploy edge (nginx with LAN configs)
3. Test LAN access to verify network and proxy working
4. Deploy authentik
5. Deploy applications
6. Test all services on LAN
7. Add WAN configurations to nginx
8. Configure port forwarding
9. Configure public DNS
10. Test WAN access

### For WAN-First Setup
1. Deploy infrastructure
2. Configure public DNS pointing to your IP
3. Configure port forwarding
4. Deploy edge with basic nginx
5. Deploy authentik (must be accessible from WAN for forward-auth)
6. Configure authentik forward-auth in nginx
7. Deploy applications with WAN nginx configs
8. Test WAN access
9. Optionally add LAN configs

## Testing Access Patterns

### Test LAN Access
```bash
# From a machine on your LAN
curl -I http://bookstack.geek
# Should return 200 OK

# DNS resolution
nslookup bookstack.geek
# Should return LAN IP
```

### Test WAN Access
```bash
# From external network or using public IP
curl -I https://bookstack.johnnyblabs.com
# Should redirect to auth or return authenticated page

# DNS resolution
nslookup bookstack.johnnyblabs.com
# Should return public IP
```

### Test Authentication
```bash
# Should redirect to Authentik
curl -L https://bookstack.johnnyblabs.com
# Follow redirects and verify Authentik login page
```

## Security Considerations

### LAN Security
- LAN is trusted, but consider:
  - Guest network isolation
  - Network segmentation
  - VLANs for IoT devices
  - Still use HTTPS for sensitive data

### WAN Security
- **Always use HTTPS** (TLS certificates required)
- **Always use authentication** (Authentik forward-auth)
- **Rate limiting** on nginx
- **Fail2ban** for brute force protection
- **Regular updates** of all components
- **Strong passwords** for all services
- **2FA** enabled in Authentik

### Certificate Management
- **LAN**: Self-signed or internal CA (e.g., step-ca, easy-rsa)
- **WAN**: Let's Encrypt or commercial CA
- Automate renewal (certbot for Let's Encrypt)

## Troubleshooting

### LAN access not working
- Check DNS resolution: `nslookup bookstack.geek`
- Verify nginx is running: `docker ps | grep nginx`
- Check nginx config: `docker exec geek-nginx nginx -t`
- Review nginx logs: `docker logs geek-nginx`

### WAN access not working
- Verify public DNS: `nslookup bookstack.johnnyblabs.com`
- Check port forwarding on router
- Verify firewall allows 80/443
- Check Authentik is running: `docker ps | grep authentik`
- Review Authentik logs: `docker logs authentik-server`

### Authentication loop
- Check Authentik outpost configuration
- Verify nginx forward-auth configuration
- Check Authentik application settings
- Review browser cookies (clear if needed)

## Example: Complete Nginx Configuration

See `stacks/00-edge/nginx/etc-nginx-docker/` for example configurations.

## References

- [Nginx proxy configuration](docs/nginx.md)
- [Authentik forward-auth setup](docs/authentik.md)
- [Security model](docs/security.md)
