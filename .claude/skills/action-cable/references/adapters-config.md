# Adapter Configuration

## Solid Cable Configuration

Solid Cable is the Rails 8 default — a database-backed adapter that eliminates Redis dependency.

### Installation

```bash
bin/rails solid_cable:install
```

This generates:
- Updates `config/cable.yml`
- Creates `db/cable_schema.rb`
- You must manually update `config/database.yml`

### Database Configuration

```yaml
# config/database.yml
production:
  primary:
    <<: *default
    database: myapp_production
  cable:
    <<: *default
    database: myapp_production_cable
    migrations_paths: db/cable_migrate
```

```yaml
# config/cable.yml
production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

### Solid Cable Options

| Option | Default | Description |
|--------|---------|-------------|
| `polling_interval` | `0.1.seconds` | How often to poll for new messages |
| `message_retention` | `nil` | How long to keep messages (set to prevent table bloat) |
| `connects_to` | — | Database connection config |
| `silence_polling` | `true` | Suppress polling query logs |

### When to Use Solid Cable vs Redis

**Solid Cable wins when:**
- You want fewer infrastructure dependencies
- Message volume is moderate (<1000/sec)
- You're already running a database
- Simplicity matters more than absolute lowest latency

**Redis wins when:**
- Very high message throughput (thousands/sec)
- Sub-millisecond latency matters
- You already have Redis infrastructure
- You're running multiple app servers that need shared state beyond just pub/sub

## Redis Adapter Configuration

### Basic Setup

```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL", "redis://localhost:6379/1") %>
  channel_prefix: myapp_production
```

### With SSL/TLS

```yaml
production:
  adapter: redis
  url: rediss://redis.example.com:6380
  channel_prefix: myapp_production
  ssl_params:
    ca_file: "/path/to/ca.crt"
```

### With Sentinel

```yaml
production:
  adapter: redis
  url: redis://mymaster
  sentinels:
    - host: sentinel1.example.com
      port: 26379
    - host: sentinel2.example.com
      port: 26379
  channel_prefix: myapp_production
```

### Channel Prefix

**Always set `channel_prefix` in production** to avoid collisions when multiple apps share a Redis instance.

## PostgreSQL Adapter

Uses PostgreSQL's `NOTIFY`/`LISTEN` mechanism. No additional dependencies needed.

```yaml
production:
  adapter: postgresql
```

**Limitations:**
- 8KB payload limit per notification (PostgreSQL constraint)
- Uses the application's database connection pool
- Not suitable for very high-throughput scenarios

**When to use:** You're already on PostgreSQL, message payloads are small, and you don't want to add Redis or set up Solid Cable.

## Deployment

### Puma Configuration (Most Common)

```ruby
# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Action Cable needs at least as many DB connections as threads
# config/database.yml pool should be >= threads_count
```

### Nginx Reverse Proxy

```nginx
upstream app {
  server 127.0.0.1:3000;
}

server {
  listen 443 ssl;

  location /cable {
    proxy_pass http://app;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # WebSocket timeout — increase from default 60s
    proxy_read_timeout 300s;
    proxy_send_timeout 300s;
  }

  location / {
    proxy_pass http://app;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

### Standalone Cable Server

For high-volume apps, run the cable server separately:

```ruby
# cable/config.ru
require_relative "../config/environment"
Rails.application.eager_load!
run ActionCable.server
```

```bash
bundle exec puma -p 28080 cable/config.ru
```

```ruby
# config/environments/production.rb
config.action_cable.mount_path = nil
config.action_cable.url = "wss://cable.yourdomain.com"
```

### Health Checks

```ruby
# config/routes.rb
get "/cable/health", to: proc { [200, {}, ["OK"]] }
```
