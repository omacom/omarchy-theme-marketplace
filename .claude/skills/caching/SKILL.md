---
name: caching
description: Expert guidance for Rails caching — fragment caching, Russian doll caching, cache keys/versioning, low-level caching (Rails.cache), conditional GET (stale?/fresh_when), and cache stores (Solid Cache, Redis, Memcached). Use when implementing cache, caching, fragment cache, Russian doll, Rails.cache, Solid Cache, cache key, HTTP caching, stale?, fresh_when, cache store, or optimizing performance.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails dev:cache), Bash(bin/rails runner *)
---

# Rails Caching Expert

Implement fast, correct caching in Rails applications. Prefer cache correctness over cache coverage — stale data is worse than slow data.

## Philosophy

**Core Principles:**
1. **Cache correctness first** — A cache miss is slow; stale data is a bug
2. **Invalidation is the hard part** — Every cache you add is a cache you must invalidate
3. **Measure before caching** — Don't cache what isn't slow
4. **Solid Cache is the Rails 8 default** — Use it unless you have a specific reason not to
5. **Fragment caching is your bread and butter** — Start here, not with low-level caching

**Caching Hierarchy (prefer top over bottom):**
```
HTTP Caching (stale?/fresh_when)     ← Fastest: never even hits your app
Fragment Caching (cache helper)       ← Fast: skips view rendering
Collection Caching (cached: true)     ← Fast: batch cache reads
Low-Level Caching (Rails.cache)       ← Flexible: cache any computation
SQL Caching (automatic per-request)   ← Free: Rails does this for you
```

## When To Use This Skill

- Adding caching to views, partials, or expensive computations
- Setting up cache stores (Solid Cache, Redis, Memcached)
- Implementing Russian doll caching with proper invalidation
- Adding HTTP conditional GET support (ETags, Last-Modified)
- Debugging stale cache issues or cache invalidation problems
- Optimizing performance with caching strategies

## Instructions

### Step 1: Determine What to Cache

**Before writing any cache code, identify the bottleneck:**

```bash
# Check logs for slow queries or renders
grep "Completed" log/development.log | sort -t= -k2 -rn | head -20

# Use rack-mini-profiler or Rails server timing
# Look for: slow partials, N+1 queries, expensive computations
```

**Good candidates for caching:**
- Partials rendered in loops (product cards, comment lists)
- Expensive computations (reports, aggregations, API calls)
- Rarely-changing content (navigation, footer, settings)
- External API responses

**Bad candidates for caching:**
- Content that changes every request (CSRF tokens, flash messages)
- User-specific content without user-scoped keys
- Content behind authentication without proper key scoping
- Anything that writes to the database

### Step 2: Choose the Right Cache Strategy

| Strategy | Use When | Cache Key Based On |
|----------|----------|-------------------|
| Fragment cache | Caching a chunk of view HTML | Record + template digest |
| Collection cache | Rendering a collection of partials | Each record individually |
| Russian doll | Nested fragments with shared invalidation | Record hierarchy with `touch` |
| Low-level cache | Caching computation results, API calls | Custom key you define |
| Conditional GET | Entire response hasn't changed | ETag or Last-Modified |

### Step 3: Implement Fragment Caching

**Basic fragment cache:**

```erb
<% cache product do %>
  <%= render product %>
<% end %>
```

Rails generates a key like: `views/products/show:abc123/products/1-20260101120000000000`

The key includes:
- Template tree digest (changes when template changes)
- Record's `cache_key_with_version` (changes when record updates)

**Conditional caching:**

```erb
<% cache_if !current_user&.admin?, product do %>
  <%= render product %>
<% end %>
```

**Multi-part cache keys for user-specific or locale-specific content:**

```erb
<% cache [current_user, I18n.locale, product] do %>
  <%= render product %>
<% end %>
```

**Include the user in the cache key when content varies by user.** Without it, you'll cache "Welcome, Ryan" and serve it to every visitor — this is the most common caching mistake.

### Step 4: Use Collection Caching for Lists

**Instead of caching each item in a loop, use collection caching:**

```erb
<%# SLOW — one cache read per item %>
<% @products.each do |product| %>
  <% cache product do %>
    <%= render partial: "products/product", locals: { product: product } %>
  <% end %>
<% end %>

<%# FAST — batch cache read (multi-fetch) %>
<%= render partial: "products/product", collection: @products, cached: true %>
```

Collection caching reads all cache entries in one round trip. This is significantly faster for large collections.

**Custom cache keys for collections:**

```erb
<%= render partial: "products/product",
           collection: @products,
           cached: ->(product) { [I18n.locale, product] } %>
```

### Step 5: Implement Russian Doll Caching

Russian doll = nested cache fragments where inner cache busting propagates outward via `touch`.

**The view:**

```erb
<% cache @category do %>
  <h2><%= @category.name %></h2>
  <% @category.products.each do |product| %>
    <% cache product do %>
      <%= render product %>
    <% end %>
  <% end %>
<% end %>
```

**The models — `touch: true` propagates cache invalidation up the chain:**

```ruby
class Category < ApplicationRecord
  has_many :products
end

class Product < ApplicationRecord
  belongs_to :category, touch: true
end
```

When a product updates → its `updated_at` changes → `touch: true` updates category's `updated_at` → both cache fragments expire.

**Without `touch: true`, the outer cache serves stale data** — updating a product won't change the category's `updated_at`, so the category fragment never expires. Every `belongs_to` in a Russian doll chain needs `touch: true`.

**Multi-level touch chains:**

```ruby
class Store < ApplicationRecord
  has_many :categories
end

class Category < ApplicationRecord
  belongs_to :store, touch: true
  has_many :products
end

class Product < ApplicationRecord
  belongs_to :category, touch: true
  # Updating a product touches category, which touches store
end
```

### Step 6: Low-Level Caching with Rails.cache

**Use `fetch` — it handles read + write in one call:**

```ruby
class Product < ApplicationRecord
  def competing_price
    Rails.cache.fetch("#{cache_key_with_version}/competing_price", expires_in: 12.hours) do
      Competitor::API.find_price(id)
    end
  end
end
```

**Key rules for low-level caching:**

1. **Use `cache_key_with_version` for AR records** — it auto-invalidates when the record updates
2. **Set `expires_in`** — unbounded caches accumulate stale data that's hard to debug
3. **Cache IDs or primitives, not Active Record objects** — cached AR objects become stale and break on code reloads

```ruby
# Avoid — cached AR objects go stale and break on code reloads
Rails.cache.fetch("super_admins", expires_in: 12.hours) do
  User.super_admins.to_a
end

# Better — cache IDs, re-query fresh
ids = Rails.cache.fetch("super_admin_ids", expires_in: 12.hours) do
  User.super_admins.pluck(:id)
end
User.where(id: ids)
```

**Other cache operations:**

```ruby
Rails.cache.read("key")                    # Returns nil on miss
Rails.cache.write("key", value, expires_in: 1.hour)
Rails.cache.delete("key")
Rails.cache.exist?("key")
Rails.cache.increment("counter")
Rails.cache.decrement("counter")

# Delete by pattern (not supported by all stores)
Rails.cache.delete_matched("products/*")

# fetch_multi for batch operations
Rails.cache.fetch_multi("key1", "key2", "key3", expires_in: 1.hour) do |key|
  expensive_computation(key)
end
```

### Step 7: HTTP Conditional GET (stale? / fresh_when)

**This is the most impactful cache — it prevents the response from being generated at all.**

**Use `stale?` when you have custom response logic:**

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])

    if stale?(@product)
      respond_to do |format|
        format.html
        format.json { render json: @product }
      end
    end
    # If fresh, Rails auto-sends 304 Not Modified
  end
end
```

**Use `fresh_when` for simple cases (default template rendering):**

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])
    fresh_when @product
    # That's it — renders template if stale, 304 if fresh
  end

  def index
    @products = Product.all
    fresh_when @products
  end
end
```

**With explicit options:**

```ruby
fresh_when last_modified: @product.updated_at.utc, etag: @product.cache_key_with_version
```

**For content that never changes:**

```ruby
def show
  http_cache_forever(public: true) do
    render
  end
end
```

**When to use conditional GET:**
- Show pages for individual records
- Index pages with predictable update patterns
- API endpoints where clients cache responses
- Static-ish pages (about, terms, etc.)

### Step 8: Configure Cache Store

#### Solid Cache (Rails 8 Default — Use This)

Database-backed caching using SSDs. No extra infrastructure needed.

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

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

```yaml
# config/cache.yml
default: &default
  store_options:
    max_age: <%= 60.days.to_i %>
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>
```

**Why Solid Cache:**
- Zero infrastructure — it's just your database
- Larger storage than RAM-based stores (SSDs are cheap)
- FIFO eviction with configurable max_age
- Supports encryption for sensitive cached data
- Supports sharding for horizontal scaling

**Other stores:** Redis (`:redis_cache_store`), Memory (`:memory_store`), Null (`:null_store`). See `references/cache-stores.md` for Redis production configuration with error handling, and full store comparison.

### Step 9: Enable Caching in Development

```bash
bin/rails dev:cache    # Toggle caching on/off
```

This creates/removes `tmp/caching-dev.txt` and toggles `perform_caching`.

**To use Solid Cache in development:**

```ruby
# config/environments/development.rb
config.cache_store = :solid_cache_store
```

And add the cache database to `config/database.yml` under development.

### Step 10: Test Cache Behavior

**Test that caching works correctly, not that Rails caching works:**

```ruby
class ProductTest < ActiveSupport::TestCase
  test "competing_price is cached" do
    product = products(:widget)

    # First call hits the API
    assert_equal 29.99, product.competing_price

    # Verify cache was written
    assert Rails.cache.exist?("#{product.cache_key_with_version}/competing_price")
  end

  test "touch propagation invalidates parent cache" do
    category = categories(:electronics)
    product = products(:widget)

    old_updated_at = category.updated_at
    product.update!(name: "New Name")

    assert_operator category.reload.updated_at, :>, old_updated_at
  end
end
```

**In request tests, verify conditional GET:**

```ruby
class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "returns 304 when product unchanged" do
    product = products(:widget)

    get product_path(product)
    assert_response :success
    etag = response.headers["ETag"]

    get product_path(product), headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified
  end
end
```

## Common Mistakes

### 1. Caching User-Specific Content Without User Key

```erb
<%# Wrong: all users see the same cached content %>
<% cache @dashboard do %>
  Welcome, <%= current_user.name %>!
  <%= render @dashboard.widgets %>
<% end %>

<%# Fixed: include user in cache key %>
<% cache [current_user, @dashboard] do %>
  Welcome, <%= current_user.name %>!
  <%= render @dashboard.widgets %>
<% end %>
```

### 2. Missing touch on Associations

```ruby
# Problem: updating a comment doesn't expire the post cache
class Comment < ApplicationRecord
  belongs_to :post
end

# Fixed: touch propagates invalidation to parent
class Comment < ApplicationRecord
  belongs_to :post, touch: true
end
```

### 3. Caching Active Record Objects

```ruby
# Problem: cached AR objects become stale and break on code reload
Rails.cache.fetch("featured") { Product.featured.to_a }

# Fixed: cache IDs, re-query fresh
ids = Rails.cache.fetch("featured_ids", expires_in: 1.hour) { Product.featured.pluck(:id) }
Product.where(id: ids)
```

### 4. No Expiration on Low-Level Cache

```ruby
# Problem: cache lives forever, exchange rates go stale silently
Rails.cache.fetch("exchange_rates") { ExchangeRateAPI.current }

# Fixed: set expires_in so data refreshes
Rails.cache.fetch("exchange_rates", expires_in: 1.hour) { ExchangeRateAPI.current }
```

See `references/fragment-caching.md` for additional common mistakes including cache key dependency issues and helper digest gotchas.

## Quick Reference: Cache Key Methods

| Method | Returns | Use For |
|--------|---------|---------|
| `cache_key` | `products/1` | Stable key (no version) |
| `cache_key_with_version` | `products/1-20260101120000` | Key + timestamp version |
| `cache_version` | `20260101120000` | Just the version stamp |
| `to_param` | `"1"` | Fallback for non-AR objects |

## Reference

For detailed patterns, edge cases, and advanced configuration, see the `references/` directory:
- `references/fragment-caching.md` — Cache keys, composite keys, collection caching, dependencies
- `references/russian-doll.md` — Nested caching, touch propagation, counter caches
- `references/low-level-caching.md` — Rails.cache.fetch, fetch_multi, atomic operations
- `references/conditional-get.md` — stale?, fresh_when, ETags, HTTP caching
- `references/cache-stores.md` — Store comparison, Solid Cache, Redis, Memcached config
- `references/performance.md` — N+1 cache calls, warming, stampede prevention, debugging
