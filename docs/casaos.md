# CasaOS

## Overview
CasaOS is a host-level service that provides a home management dashboard. It runs directly on the host machine (not containerized) and is accessed via port 8888.

## Platform Decision
**CasaOS is intentionally NOT proxied through the homelab-platform Nginx reverse proxy.**

Rationale:
- CasaOS runs at the host level, not in Docker
- It is designed for LAN-only access
- Proxying would require container→host dependencies via `host.docker.internal`
- This violates the platform's clean architecture where Nginx only proxies containerized services

## Access Methods

### Direct LAN Access (Recommended)
CasaOS is accessible directly on port 8888 from any device on your local network:

```
http://<host-ip>:8888
```

Examples:
- Using hostname: `http://geek:8888` (if your LAN DNS resolves the hostname)
- Using IP: `http://192.168.1.100:8888` (replace with your actual host IP)
- Localhost: `http://127.0.0.1:8888` (when accessing from the host itself)

### Service Details
- **Process**: casaos-gateway (typically PID ~2829)
- **Port**: 8888 (bound to all interfaces: `*:8888`)
- **Protocol**: HTTP
- **Access Scope**: LAN-only

## Security Considerations

### Network Isolation
CasaOS should be restricted to LAN access only. Ensure your firewall is configured to block external access to port 8888.

#### Recommended Firewall Configuration
If using UFW (Uncomplicated Firewall):

```bash
# Allow CasaOS from local network only (these specific rules take precedence)
sudo ufw allow from 192.168.0.0/16 to any port 8888 proto tcp comment 'CasaOS LAN access'
sudo ufw allow from 10.0.0.0/8 to any port 8888 proto tcp comment 'CasaOS LAN access'
sudo ufw allow from 172.16.0.0/12 to any port 8888 proto tcp comment 'CasaOS LAN access'

# Verify rule order (specific allows should come before any general deny)
sudo ufw status numbered
```

Note: UFW processes rules in order. If you have a general deny-all rule, ensure the above allow rules come first. Use `sudo ufw insert <position>` to adjust rule order if needed.

If using iptables directly:

```bash
# Allow CasaOS from RFC1918 private networks
sudo iptables -A INPUT -p tcp --dport 8888 -s 192.168.0.0/16 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8888 -s 10.0.0.0/8 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8888 -s 172.16.0.0/12 -j ACCEPT

# Deny all other access to port 8888
sudo iptables -A INPUT -p tcp --dport 8888 -j DROP

# Save rules (Debian/Ubuntu)
sudo netfilter-persistent save
```

### No Authentication via Authentik
Because CasaOS is not proxied through Nginx, it does NOT benefit from Authentik forward-auth protection. Ensure CasaOS has its own authentication configured if needed.

### TLS/HTTPS
CasaOS runs on HTTP by default. If TLS is required:
- Configure CasaOS's built-in TLS support (if available)
- OR use a separate reverse proxy on the host (not the containerized Nginx)

## Internal Services
CasaOS also runs several internal services bound to `127.0.0.1` on random high ports. These are normal and required for CasaOS operation. The only port you need to access is 8888.

## Validation

### Check if CasaOS is Running
```bash
# Check the process
ps aux | grep casaos-gateway

# Check the port binding
sudo netstat -tlnp | grep :8888
# or
sudo ss -tlnp | grep :8888
```

Expected output:
```
tcp        0      0 0.0.0.0:8888            0.0.0.0:*               LISTEN      2829/casaos-gateway
```

### Test Access from LAN
From any device on your local network:
```bash
curl http://<host-ip>:8888
```

You should receive the CasaOS web interface HTML response.

## Troubleshooting

### Cannot Access CasaOS
1. Verify CasaOS is running:
   ```bash
   # Check for casaos related services (actual service name may vary)
   systemctl list-units | grep -i casa
   
   # Common service names to try:
   systemctl status casaos
   systemctl status casaos-gateway
   systemctl status casa-os
   
   # Or check the process directly
   ps aux | grep casaos
   ```

2. Check firewall rules:
   ```bash
   sudo ufw status verbose  # if using UFW
   sudo iptables -L -n -v   # if using iptables
   ```

3. Verify port is listening:
   ```bash
   sudo ss -tlnp | grep :8888
   ```

4. Check if you can access from localhost:
   ```bash
   curl http://127.0.0.1:8888
   ```

### Port Already in Use
If port 8888 is already in use by another service, you'll need to reconfigure CasaOS to use a different port. Consult CasaOS documentation for port configuration.

## Architecture Notes
This configuration maintains clean separation between:
- **Host-level services**: CasaOS (accessed directly)
- **Containerized platform services**: Nginx, Authentik, apps (accessed via Nginx reverse proxy)

This approach:
- Avoids complex container→host networking
- Maintains platform architecture principles
- Provides clear access patterns
- Reduces coupling between the homelab platform and host-level tools
