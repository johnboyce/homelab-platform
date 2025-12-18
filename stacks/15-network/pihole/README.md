# Pi-hole Stack

Network-wide DNS and ad-blocking service.

## Functionality

- DNS server with ad-blocking
- DHCP server (optional)
- Web interface for management

## Dependencies

None - standalone service

## Environment Variables

Required in `/etc/homelab/secrets/pihole.env`:
- `PIHOLE_WEB_PASSWORD` - Web interface password
- `PIHOLE_HOST_IP` - Host IP address

## Ports

- `53/tcp` and `53/udp` - DNS
- `67/udp` - DHCP (optional, commented out by default)

## Accessing

- Web UI: http://pi.hole/admin (requires DNS pointing to Pi-hole)
- Or configure via Nginx proxy: https://pihole.johnnyblabs.com

## Notes

Pi-hole's web interface is accessible internally on the `geek-infra` network. To access from outside:
1. Add Nginx proxy configuration to expose it
2. Or expose port 80 in docker-compose.yml with `- "8081:80"` (example)
3. Currently only DNS port 53 is exposed to the host

1. Point devices to use this server as DNS
2. Configure via web interface
3. Add custom DNS entries and blocklists

## Notes

- Requires `NET_ADMIN` capability for DNS operations
- DNS ports (53) must not conflict with other services
