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
To proxy requests to services running on the Docker host (not in containers), use 
`host.docker.internal` as the upstream hostname:

```nginx
proxy_pass http://host.docker.internal:8888;
```

This requires the `extra_hosts` configuration in docker-compose.yml:
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

The `host-gateway` special value automatically resolves to the host's IP address, making 
this configuration portable across different hosts without hardcoding IP addresses. This 
is the recommended best practice for Docker on Linux.

## Landing Page
The default server (`00_geek.conf`) serves a beautiful landing page from `html/index.html` that provides:
- Visual status indicator for the platform
- Quick access links to services (e.g., CasaOS at `/casaos/`)
- Responsive design for desktop and mobile
- Modern gradient UI matching the GEEK platform branding

## Validation
- `docker exec geek-nginx nginx -t`
- `curl -H 'Host: <vhost>' http://127.0.0.1`
