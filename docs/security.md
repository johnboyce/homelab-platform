# Security

## Trust boundaries
- **WAN**: always authenticated (Authentik forward-auth)
- **LAN**: may be allowlisted at Nginx (unauth) or also protected by Authentik

## Secrets handling
Secrets must never be committed to git.
Operator places secrets on-host, typically under:
- `/etc/homelab/secrets/`

## TLS certificates
Certificates are host-owned and mounted read-only into the Nginx container.
Supported patterns:
- `/etc/nginx-docker/certs/` (simpler)
- `/etc/ssl/homelab/<domain>/` (cleaner separation)
