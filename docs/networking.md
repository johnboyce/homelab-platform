# Networking

## Shared platform network (explicit)
A shared Docker network is used for service discovery and proxying:

- Network name: `geek-infra`
- Created explicitly via `make bootstrap` / `scripts/bootstrap_host.sh`

All platform services that must communicate (nginx, authentik, apps) attach to this network.

## Proxying rule
Nginx proxies to upstreams by **Docker service name** on `geek-infra`.
Do not proxy to host IPs. Do not rely on container IPs.

## Port exposure
Only the Nginx edge stack binds host ports 80/443.
All other services remain internal unless explicitly required for bootstrap/debug.
