# Redis Stack

Shared Redis 7 cache instance used by platform applications.

## Used By

- Authentik (sessions and caching)
- (Other applications can use as needed)

## Environment Variables

Required in `/etc/homelab/secrets/redis.env`:
- `REDIS_PASSWORD` - Authentication password

## Accessing

```bash
# Test connection
docker exec geek-redis redis-cli -a <password> ping

# Interactive CLI
docker exec -it geek-redis redis-cli -a <password>
```
