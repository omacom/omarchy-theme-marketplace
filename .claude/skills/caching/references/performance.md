# Caching Performance Patterns

## Avoid N+1 Cache Calls

```ruby
# BAD: N+1 cache reads
@products.each do |product|
  Rails.cache.fetch("product_#{product.id}/price") { product.compute_price }
end

# GOOD: Batch cache read
keys = @products.map { |p| "product_#{p.id}/price" }
Rails.cache.fetch_multi(*keys, expires_in: 1.hour) do |key|
  id = key.split("_")[1].split("/").first
  Product.find(id).compute_price
end
```

## Cache Warming

Pre-populate caches after deploy or data migration:

```ruby
# lib/tasks/cache.rake
namespace :cache do
  desc "Warm product caches"
  task warm_products: :environment do
    Product.find_each do |product|
      Rails.cache.fetch("#{product.cache_key_with_version}/full", expires_in: 1.day) do
        ProductSerializer.new(product).as_json
      end
    end
  end
end
```

## Fragment Cache + eager_load

```ruby
# Controller
def show
  @post = Post.includes(:comments, :author).find(params[:id])
  fresh_when @post
end
```

Even with fragment caching, eager-load associations for cache misses.

## Cache Stampede Prevention

Multiple patterns to prevent thundering herd:

```ruby
# 1. race_condition_ttl (built-in)
Rails.cache.fetch("key", expires_in: 1.hour, race_condition_ttl: 10.seconds) { ... }

# 2. Stale-while-revalidate (HTTP level)
expires_in 1.hour, public: true, stale_while_revalidate: 60.seconds

# 3. Background refresh (via Solid Queue or Sidekiq)
class CacheRefreshJob < ApplicationJob
  def perform(cache_key)
    value = expensive_computation
    Rails.cache.write(cache_key, value, expires_in: 1.hour)
  end
end
```

## Jittering Expirations

Prevent cache stampedes by adding randomness:

```ruby
# Instead of every cache expiring at exactly 1 hour:
expires_in: (55..65).to_a.sample.minutes

# Or in a helper:
def jittered_ttl(base, jitter: 0.1)
  variation = base * jitter
  base + rand(-variation..variation)
end

Rails.cache.fetch("key", expires_in: jittered_ttl(1.hour)) { ... }
```

## Testing Caching

### Test Cache Invalidation, Not Rails Internals

```ruby
class ProductCacheTest < ActiveSupport::TestCase
  test "updating product expires its cache" do
    product = products(:widget)

    # Write to cache
    Rails.cache.write("product_#{product.id}", product.name)

    # Verify cache exists
    assert_equal "Widget", Rails.cache.read("product_#{product.id}")
  end

  test "touch propagation works through association chain" do
    category = categories(:electronics)
    product = products(:widget)

    original = category.updated_at
    product.update!(name: "Updated Widget")

    assert_operator category.reload.updated_at, :>, original
  end
end
```

### Test Environment Configuration

```ruby
# config/environments/test.rb

# Option A: Disable caching entirely (simpler tests)
config.cache_store = :null_store

# Option B: Use memory store (test cache behavior)
config.cache_store = :memory_store

# Clear cache between tests
# test/test_helper.rb
class ActiveSupport::TestCase
  teardown do
    Rails.cache.clear
  end
end
```

## Debugging & Troubleshooting

### Check If Caching Is Enabled

```ruby
# In console
Rails.application.config.action_controller.perform_caching  # Fragment caching
Rails.cache.class  # What store is active

# Toggle in development
# bin/rails dev:cache
```

### View Cache Hits/Misses in Logs

```
# In development.log:
Read fragment views/products/1-20260101/abc123 (0.5ms)        # HIT
Write fragment views/products/1-20260101/abc123 (1.2ms)       # MISS → WRITE
```

### Inspect Cache Contents

```ruby
# Read a specific key
Rails.cache.read("key")

# Check existence
Rails.cache.exist?("key")

# For Solid Cache — query the database directly
SolidCache::Entry.count
SolidCache::Entry.where("key_hash LIKE ?", "%products%").count
```

### Clear All Caches

```ruby
Rails.cache.clear                          # Clear cache store
ActionView::Digestor.cache.clear           # Clear template digest cache
```

```bash
bin/rails tmp:cache:clear                  # Clear file-based cache
```

### Common Stale Cache Symptoms

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Updated record shows old data | Missing `touch: true` | Add `touch: true` to `belongs_to` |
| Template change not reflected | Template digest not updating | Check for undetected dependencies |
| Different users see same content | Missing user in cache key | Add `current_user` to cache key array |
| Cache never expires | No `expires_in` set | Always set expiration on `fetch`/`write` |
| Slow first page load after deploy | Cache cold start | Implement cache warming |
| All caches expire at once | Same `expires_in` for everything | Jitter expirations |
