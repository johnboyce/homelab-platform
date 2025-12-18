# Nginx (Edge)

## Critical rule: minimal mounts
Do not mount the entire `/etc/nginx` into the container.
Mount only:
- `nginx.conf`
- `conf.d/`
- `snippets/`
- `certs/` (read-only)

Mounting the full directory is known to break default Nginx files (e.g., mime.types).

## Configuration approach
This homelab uses the **conf.d/** pattern for nginx virtual host configurations.

- All active server configurations go in `conf.d/`
- Files are named with numeric prefixes for load order (e.g., `00_geek.conf`, `10_auth.johnnyblabs.com.conf`)
- No symlink management required (unlike sites-available/sites-enabled)
- Standard for Docker/containerized nginx deployments

**Why conf.d/ instead of sites-available/sites-enabled?**
- Simpler for containerized deployments
- No enable/disable management needed in a homelab
- Standard for nginx:alpine Docker image
- All configs are explicit and version-controlled

## Deployment model
- Reference nginx tree lives in: `stacks/00-edge/nginx/etc-nginx-docker/`
- Runtime nginx tree lives on host: `/etc/nginx-docker/`
- Deploy script syncs repo → host, excluding cert contents.

## Validation
- `docker exec geek-nginx nginx -t`
- `curl -H 'Host: <vhost>' http://127.0.0.1`
