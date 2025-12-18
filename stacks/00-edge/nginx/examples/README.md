# Example Nginx Configuration Templates

This directory contains example Nginx configuration files for various access patterns.

## Files

- `bookstack-lan.conf` - LAN-only access (no authentication)
- `bookstack-wan.conf` - WAN access with Authentik forward-auth
- `authentik.conf` - Authentik server (required for both LAN and WAN)
- `pihole-lan.conf` - Pi-hole LAN access (DNS admin)
- `cockpit-lan.conf` - Cockpit LAN access (system admin)

## Usage

1. Choose the appropriate configuration file for your access pattern
2. Replace variables:
   - `${PUBLIC_DOMAIN}` → Your domain (e.g., `johnnyblabs.com`)
   - `${INTERNAL_DOMAIN}` → Your internal domain (e.g., `geek`)
3. Copy to `/etc/nginx-docker/conf.d/`
4. Reload Nginx: `docker exec geek-nginx nginx -s reload`

## See Also

- `docs/access-patterns.md` - Detailed explanation of LAN vs WAN access
- `docs/nginx.md` - Nginx configuration guide
