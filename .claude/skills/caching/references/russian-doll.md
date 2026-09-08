# Russian Doll Caching Patterns

## Basic Two-Level Nesting

```erb
<%# app/views/categories/show.html.erb %>
<% cache @category do %>
  <h2><%= @category.name %></h2>
  <%= render partial: "products/product", collection: @category.products, cached: true %>
<% end %>
```

```ruby
class Product < ApplicationRecord
  belongs_to :category, touch: true
end
```

## Three-Level Nesting

```erb
<%# app/views/stores/show.html.erb %>
<% cache @store do %>
  <% @store.categories.each do |category| %>
    <% cache category do %>
      <h3><%= category.name %></h3>
      <% category.products.each do |product| %>
        <% cache product do %>
          <%= render product %>
        <% end %>
      <% end %>
    <% end %>
  <% end %>
<% end %>
```

```ruby
class Product < ApplicationRecord
  belongs_to :category, touch: true
end

class Category < ApplicationRecord
  belongs_to :store, touch: true
  has_many :products
end
```

## Touch Propagation Patterns

```ruby
# Simple touch
belongs_to :post, touch: true

# Touch with specific timestamp column
belongs_to :post, touch: :comments_updated_at

# Conditional touch
after_save :touch_post, if: :published?
def touch_post
  post.touch
end

# Manual touch (useful in service objects)
@post.touch  # Updates updated_at
@post.touch(:reviewed_at)  # Updates a specific column
```

## When Touch Gets Expensive

If updating a child record touches hundreds of parents, consider:

```ruby
# Instead of touch cascading through everything:
class Comment < ApplicationRecord
  belongs_to :post, touch: true  # This touches post → author → ...
end

# Use targeted cache expiration:
class Comment < ApplicationRecord
  belongs_to :post

  after_commit :expire_post_cache, on: [:create, :update, :destroy]

  private

  def expire_post_cache
    Rails.cache.delete("post_comments_count/#{post_id}")
    post.touch  # Only touch one level
  end
end
```

## Counter Caches

Counter caches avoid `COUNT(*)` queries. Not strictly "caching" but a key performance pattern.

```ruby
# Migration
add_column :posts, :comments_count, :integer, default: 0, null: false

# Model
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
end

# Usage — no SQL COUNT query
@post.comments_count  # Reads the column directly

# Reset if data gets out of sync
Comment.counter_culture_fix_counts  # If using counter_culture gem
# Or manually:
Post.find_each do |post|
  Post.reset_counters(post.id, :comments)
end
```

### Custom Counter Cache Column

```ruby
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: :total_comments
end
```

### Conditional Counter Cache (via counter_culture gem)

```ruby
# Gemfile
gem "counter_culture"

class Comment < ApplicationRecord
  belongs_to :post
  counter_culture :post,
    column_name: proc { |comment| comment.approved? ? "approved_comments_count" : nil }
end
```
