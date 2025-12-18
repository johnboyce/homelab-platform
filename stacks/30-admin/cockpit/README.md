# Cockpit Stack

Web-based system administration dashboard.

## Functionality

- System monitoring and management
- Container management (via Docker socket)
- Terminal access
- Storage and network management
- User administration

## Dependencies

None - runs with host system access

## Environment Variables

Optional in `/etc/homelab/secrets/cockpit.env`

## Ports

- `9090` - Web interface

## Accessing

- Web UI: https://cockpit.johnnyblabs.com (via nginx proxy)
- Direct: http://localhost:9090

## Authentication

Uses PAM authentication - log in with system user credentials.

## Security Notes

- Runs in privileged mode for system management
- Has access to Docker socket for container management
- Has access to host filesystem via `/host` mount
- Should be protected behind authentication (nginx + Authentik)

## Initial Access

1. Access the web UI
2. Log in with a system user account
3. May need to configure Cockpit to allow remote access
