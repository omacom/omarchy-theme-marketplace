# Fragment Caching Deep Dive

## How Cache Keys Are Generated

When you write `<% cache product do %>`, Rails builds a key from:

1. **Prefix:** `views/`
2. **Template digest:** MD5 of the template content (and its dependencies)
3. **Record key:** `product.cache_key_with_version` → `products/1-20260101120000000000`

Full key example:
```
views/products/_product:bea67108094918eeba42cd4a6e786901/products/1-20260101120000000000
```

## Composite Cache Keys

Pass an array to scope the cache by multiple dimensions:

```erb
<%# Scoped by user, locale, and record %>
<% cache [current_user, I18n.locale, product] do %>
  ...
<% end %>

<%# Scoped by role (not individual user) %>
<% cache [current_user.role, product] do %>
  ...
<% end %>

<%# Scoped by a custom version string %>
<% cache [product, "v2"] do %>
  ...
<% end %>
```

## Conditional Fragment Caching

```erb
<%# Only cache for non-admin users %>
<% cache_if !current_user&.admin?, product do %>
  <%= render product %>
<% end %>

<%# Cache unless in preview mode %>
<% cache_unless @preview_mode, product do %>
  <%= render product %>
<% end %>
```

## Shared Partial Caching Across MIME Types

A partial used by both HTML and JS responses:

```ruby
# Works for both HTML and JS requests
render(partial: "hotels/hotel", collection: @hotels, cached: true)
# Loads hotels/hotel.erb

# Force HTML format in any context
render(partial: "hotels/hotel", collection: @hotels, formats: :html, cached: true)
# Loads hotels/hotel.html.erb even from JS templates
```

## Collection Caching with Custom Keys

```erb
<%# Default: uses each record's cache_key_with_version %>
<%= render partial: "products/product", collection: @products, cached: true %>

<%# Custom key with locale prefix %>
<%= render partial: "products/product",
           collection: @products,
           cached: ->(product) { [I18n.locale, product] } %>

<%# Custom key with current user role %>
<%= render partial: "products/product",
           collection: @products,
           cached: ->(product) { [current_user.role, product] } %>
```

**How multi-fetch works:** Rails calls `read_multi` on the cache store, fetching all entries in a single round trip. Only missed entries are rendered and written back. This is dramatically faster than individual `cache` calls in a loop.

## Cache Key Design

### Active Record Cache Keys

```ruby
product = Product.find(1)
product.cache_key                # "products/1"
product.cache_key_with_version   # "products/1-20260101120000000000"
product.cache_version            # "20260101120000000000"
```

### Custom Cache Keys

```ruby
class Dashboard
  def cache_key
    "dashboards/#{user_id}/#{Date.today}"
  end
end

# Or use arrays — Rails joins them with "/"
Rails.cache.fetch([user.id, "dashboard", Date.today]) { ... }
```

### Namespace Your Caches

```ruby
# Global namespace in config
config.cache_store = :solid_cache_store, { namespace: "myapp-v1" }

# Per-call namespace
Rails.cache.fetch("stats", namespace: "reports") { ... }
# Actual key: "reports/stats"
```

### Versioning Cache Keys for Schema Changes

When your cached data structure changes, bump the key:

```ruby
# Before: cached a simple string
Rails.cache.fetch("#{product.cache_key_with_version}/description") { ... }

# After: cached a hash — old cached strings will cause errors
# Bump the key version:
Rails.cache.fetch("#{product.cache_key_with_version}/description/v2") { ... }
```

## Managing Dependencies

### Implicit Dependencies

Rails auto-detects these render calls for cache digest computation:

```erb
<%= render partial: "comments/comment", collection: commentable.comments %>
<%= render "comments/comments" %>
<%= render @topic %>           <%# → "topics/topic" %>
<%= render topics %>           <%# → "topics/topic" %>
```

### Explicit Dependencies

When Rails can't detect the dependency (helpers, dynamic partials):

```erb
<%# Template Dependency: todolists/todolist %>
<%= render_sortable_todolists @project.todolists %>

<%# Wildcard dependency %>
<%# Template Dependency: events/* %>
<%= render_categorizable_events @person.events %>
```

### Collection Template Annotation

When a collection partial doesn't start with `cache`:

```erb
<%# Template Collection: notification %>
<% my_helper_that_calls_cache(some_arg, notification) do %>
  <%= notification.name %>
<% end %>
```

### External/Helper Dependencies

When changing a helper should bust the cache, add a version comment:

```erb
<%# Helper Dependency Updated: 2026-03-01 %>
<% cache product do %>
  <%= render_stars(product.rating) %>
<% end %>
```

Change the date whenever you update the helper.
