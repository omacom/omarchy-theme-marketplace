# Cache Store Comparison & Configuration

## Cache Store Comparison

| Feature | Solid Cache | Redis | Memcached | Memory | File |
|---------|------------|-------|-----------|--------|------|
| **Infrastructure** | None (DB) | Redis server | Memcached server | None | None |
| **Shared across processes** | ✅ | ✅ | ✅ | ❌ | ✅ (same host) |
| **Persistence** | ✅ (DB) | Configurable | ❌ | ❌ | ✅ |
| **Eviction** | FIFO | LRU/LFU | LRU | LRU | Manual |
| **Max size** | Disk (large) | RAM | RAM | Configured | Disk |
| **delete_matched** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **increment/decrement** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Encryption** | ✅ | ❌ | ❌ | N/A | ❌ |
| **Sharding** | ✅ | Manual | ✅ | N/A | N/A |
| **Speed** | ~1ms (SSD) | ~0.1ms | ~0.1ms | ~0.01ms | ~1ms |
| **Rails default (8+)** | ✅ Prod | — | — | ✅ Dev | — |

### When to Use Which

- **Solid Cache:** Default choice. No extra infra, large capacity, good enough speed for most apps.
- **Redis:** When you already run Redis (Sidekiq) and need sub-millisecond reads, or LRU eviction.
- **Memcached:** Legacy apps, multi-server setups, when you need distributed caching without Redis.
- **Memory:** Development and test only. Single-process apps.
- **File:** Low-traffic sites, development, or when you need persistence without a DB.

## Solid Cache Configuration

### Basic Setup

```yaml
# config/database.yml
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
```

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

### Tuning cache.yml

```yaml
# config/cache.yml
default: &default
  store_options:
    max_age: <%= 60.days.to_i %>     # Max age of any cache entry
    max_size: <%= 256.megabytes %>    # Total cache size limit
    namespace: <%= Rails.env %>       # Key namespace

production:
  <<: *default
  store_options:
    max_age: <%= 90.days.to_i %>
    max_size: <%= 1.gigabyte %>
```

### Sharding for Scale

```yaml
# config/database.yml
production:
  cache_shard1:
    database: cache1_production
    host: cache1-db
  cache_shard2:
    database: cache2_production
    host: cache2-db

# config/cache.yml
production:
  databases: [cache_shard1, cache_shard2]
```

### Encryption

```yaml
# config/cache.yml
production:
  encrypt: true
```

Requires Active Record Encryption to be set up in the app.

### Expiry Behavior

Solid Cache tracks writes with a counter. At 50% of `expiry_batch_size`, a background thread purges old entries. If you prefer background jobs:

```yaml
# config/cache.yml
production:
  expiry_method: :job  # Default is :thread
```

## Redis Cache Store Advanced Config

### Dedicated Cache Instance

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV["REDIS_CACHE_URL"],  # Separate from Sidekiq Redis!
  connect_timeout: 5,
  read_timeout: 0.2,
  write_timeout: 0.2,
  reconnect_attempts: 2,
  error_handler: ->(method:, returning:, exception:) {
    Rails.logger.warn("Redis cache error: #{exception.message}")
    Sentry.capture_exception(exception, level: "warning")
  }
}
```

### Redis Server Config for Caching

```
# redis.conf for cache-only instance
maxmemory 2gb
maxmemory-policy allkeys-lfu  # Redis 4+ (best for caching)
# maxmemory-policy allkeys-lru  # Redis 3
```

### Connection Pooling

```ruby
config.cache_store = :redis_cache_store, {
  url: ENV["REDIS_URL"],
  pool: { size: 16, timeout: 2 }  # Default: size=5, timeout=5
}

# Disable pooling
config.cache_store = :redis_cache_store, {
  url: ENV["REDIS_URL"],
  pool: false
}
```

## Memcached Configuration

```ruby
# Gemfile
gem "dalli"

# Config
config.cache_store = :mem_cache_store, "cache-1.example.com", "cache-2.example.com"

# With options
config.cache_store = :mem_cache_store, "cache-1.example.com", {
  pool: { size: 10, timeout: 2 },
  compress: true,
  serializer: :json
}
```

**Limitations vs Redis:**
- No `delete_matched` (no pattern scanning)
- 1MB value size limit (default)
- No persistence
- No pub/sub

## Cache Namespacing Strategies

### Per-Deploy Cache Busting

```ruby
# Bust all caches on deploy by including git SHA
config.cache_store = :solid_cache_store, {
  namespace: "myapp-#{ENV['GIT_SHA'] || 'dev'}"
}
```

### Per-Feature Namespacing

```ruby
# Isolate different features
Rails.cache.fetch("stats", namespace: "analytics", expires_in: 1.hour) { ... }
Rails.cache.fetch("feed", namespace: "social", expires_in: 5.minutes) { ... }

# Clear only one namespace
Rails.cache.delete_matched("analytics/*")
```
