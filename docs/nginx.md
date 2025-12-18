# Nginx (Edge)

## Critical rule: minimal mounts
Do not mount the entire `/etc/nginx` into the container.
Mount only:
- `nginx.conf`
- `conf.d/` (or sites-enabled)
- `snippets/`
- `certs/` (read-only)

Mounting the full directory is known to break default Nginx files (e.g., mime.types).

## Deployment model
- Reference nginx tree lives in: `stacks/00-edge/nginx/etc-nginx-docker/`
- Runtime nginx tree lives on host: `/etc/nginx-docker/`
- Deploy script syncs repo → host, excluding cert contents.

## Validation
- `docker exec geek-nginx nginx -t`
- `curl -H 'Host: <vhost>' http://127.0.0.1`
