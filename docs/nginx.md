# Nginx (Edge)

## Critical rule: minimal mounts
Do not mount the entire `/etc/nginx` into the container.
Mount only:
- `nginx.conf`
- `conf.d/`
- `snippets/`
- `certs/` (read-only)
- `html/` (read-only, for landing page)

Note: Standard nginx configuration files (mime.types, fastcgi_params, fastcgi.conf, 
uwsgi_params, scgi_params) are now included in the repository for completeness and to 
support future use cases.

## Configuration approach
This homelab uses the **conf.d/** pattern for nginx virtual host configurations.

- All active server configurations go in `conf.d/`
- Files are named with numeric prefixes for load order (e.g., `00_geek.conf`, `10_auth.johnnyblabs.com.conf`)
- No symlink management required (unlike sites-available/sites-enabled)
- Standard for Docker/containerized nginx deployments

**Snippets directory:**
- Reusable configuration blocks are stored in `snippets/`
- Example: `websocket_map.conf` defines the WebSocket upgrade mapping
- Example: `proxy_common.conf` defines standard proxy headers
- Example: `lan_only.conf` restricts access to local networks
- Include snippets with: `include /etc/nginx/snippets/<name>.conf;`

**Why conf.d/ instead of sites-available/sites-enabled?**
- Simpler for containerized deployments
- No enable/disable management needed in a homelab
- Standard for nginx:alpine Docker image
- All configs are explicit and version-controlled

## Deployment model
- Reference nginx tree lives in: `stacks/00-edge/nginx/etc-nginx-docker/`
- Runtime nginx tree lives on host: `/etc/nginx-docker/`
- Deploy script syncs repo → host, excluding cert contents.

## Accessing host services from nginx container
**Platform policy: Nginx should generally NOT proxy to host-level services.**

The homelab-platform Nginx is designed to proxy containerized services on the `geek-infra` Docker network. Host-level services should be accessed directly when possible to maintain clean architecture.

If you must proxy to a host service, use `host.docker.internal` as the upstream hostname:

```nginx
proxy_pass http://host.docker.internal:<port>;
```

This requires the `extra_hosts` configuration in docker-compose.yml:
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

The `host-gateway` special value automatically resolves to the host's IP address, making 
this configuration portable across different hosts without hardcoding IP addresses.

**Note**: This capability exists for exceptional cases only. Prefer containerized services that attach to the `geek-infra` network.

## Landing Page
The default server (`00_geek.conf`) serves a beautiful landing page from `html/index.html` that provides:
- Visual status indicator for the platform
- Quick access links to containerized platform services
- Responsive design for desktop and mobile
- Modern gradient UI matching the GEEK platform branding

Note: Host-level services (like CasaOS) are not included on the landing page as they are accessed directly, not through Nginx.

## Validation
- `docker exec geek-nginx nginx -t`
- `curl -H 'Host: <vhost>' http://127.0.0.1`
