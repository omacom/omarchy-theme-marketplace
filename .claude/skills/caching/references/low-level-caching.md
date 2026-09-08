# Low-Level Caching Patterns

## Rails.cache.fetch Patterns

```ruby
# Basic fetch with expiration
Rails.cache.fetch("site_stats", expires_in: 1.hour) do
  {
    total_users: User.count,
    total_orders: Order.count,
    revenue_today: Order.today.sum(:total)
  }
end

# Fetch with record-based key (auto-invalidates)
Rails.cache.fetch("#{product.cache_key_with_version}/full_description") do
  product.description_html  # Expensive markdown rendering
end

# Fetch with race condition TTL (prevents thundering herd)
Rails.cache.fetch("popular_products", expires_in: 1.hour, race_condition_ttl: 10.seconds) do
  Product.popular.limit(10).to_a.map(&:id)
end

# Force cache refresh
Rails.cache.fetch("key", force: true) { compute_value }
```

## race_condition_ttl Explained

When a cached value expires, multiple processes may try to regenerate it simultaneously (thundering herd). `race_condition_ttl` extends the stale entry briefly so only one process regenerates:

```ruby
Rails.cache.fetch("expensive_report", expires_in: 6.hours, race_condition_ttl: 30.seconds) do
  Report.generate_daily  # Takes 10 seconds
end
```

## fetch_multi for Batch Operations

```ruby
# Fetch multiple keys at once
results = Rails.cache.fetch_multi("user_1_stats", "user_2_stats", "user_3_stats", expires_in: 1.hour) do |key|
  user_id = key.split("_")[1]
  User.find(user_id).compute_stats
end

# With dynamic keys
keys = products.map { |p| "product_#{p.id}_price" }
prices = Rails.cache.fetch_multi(*keys, expires_in: 12.hours) do |key|
  product_id = key.split("_")[1]
  Competitor::API.find_price(product_id)
end
```

## Cache Write Options

```ruby
Rails.cache.write("key", value,
  expires_in: 1.hour,          # TTL
  expires_at: 1.hour.from_now, # Absolute expiration time
  namespace: "v2",             # Key namespace
  compress: true,              # Compress values (default for > 1KB)
  compress_threshold: 256      # Compress if value > 256 bytes
)
```

## Increment/Decrement (Atomic Operations)

```ruby
# Atomic counter operations (supported by Memcached, Redis, Solid Cache)
Rails.cache.increment("page_views/#{page.id}")
Rails.cache.decrement("remaining_credits/#{user.id}")

# With initial value and expiration
Rails.cache.increment("api_calls/#{api_key}/#{Date.today}", 1,
  initial: 0,
  expires_in: 1.day
)
```

## What NOT to Cache

```ruby
# ❌ Never cache AR objects
Rails.cache.fetch("user") { User.find(1) }

# ❌ Never cache Proc or Lambda
Rails.cache.fetch("fn") { -> { compute } }

# ❌ Never cache objects with IO handles
Rails.cache.fetch("file") { File.open("data.csv") }

# ❌ Never cache request-scoped data
Rails.cache.fetch("current_request") { request.url }

# ✅ Cache primitives: strings, numbers, arrays, hashes
Rails.cache.fetch("ids") { User.pluck(:id) }
Rails.cache.fetch("count") { Order.count }
Rails.cache.fetch("stats") { { total: 100, average: 42.5 } }
```

## SQL Caching (Automatic)

Rails automatically caches SQL query results within a single request. No configuration needed.

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all        # Hits DB
    @count = Product.all.count     # Uses cached result (same query)
  end
end
```

**Key facts:**
- Scoped to a single request (destroyed at end of action)
- Stores query string → result set mapping
- Each retrieval still instantiates new AR objects
- For persistent caching, use low-level caching instead
