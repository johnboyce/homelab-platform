# Authentik (SSO)

## Role
Authentik provides centralized authentication and SSO for WAN services.

## Key operational requirement
Nginx must be able to reach:
- authentik server
- authentik outpost

This requires:
- Nginx container attaches to the same Docker network (`geek-infra`)
- Nginx proxies by service name (not host IP)

## Deployment order
Authentik is deployed only after Nginx is stable.

## Forward-auth
Forward-auth configuration will be applied at Nginx per-vhost.
