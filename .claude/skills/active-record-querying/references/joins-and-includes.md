# Joins and Eager Loading — Complete Guide

## INNER JOIN (joins)

```ruby
# Single association
Book.joins(:author)

# Multiple associations
Book.joins(:author, :reviews)

# Nested associations
Book.joins(reviews: :customer)

# Deep nesting
Author.joins(books: [{ reviews: { customer: :orders } }, :supplier])

# String SQL (for custom joins)
Author.joins("INNER JOIN books ON books.author_id = authors.id AND books.out_of_print = FALSE")
```

## LEFT OUTER JOIN

```ruby
Customer.left_outer_joins(:orders)

# With aggregation
Customer.left_outer_joins(:orders)
  .select("customers.*, COUNT(orders.id) AS order_count")
  .group("customers.id")
```

## where.associated / where.missing

```ruby
# Records WITH the association (cleaner than joins + where not null)
Customer.where.associated(:reviews)

# Records WITHOUT the association (cleaner than left join + where null)
Customer.where.missing(:reviews)
```

## Conditions on Joined Tables

```ruby
# Hash conditions (preferred)
Book.joins(:author).where(authors: { name: "Frank Herbert" })

# Using merge with scopes (very clean)
class Review < ApplicationRecord
  scope :recent, -> { where(created_at: 1.week.ago..) }
end

Book.joins(:reviews).merge(Review.recent).distinct
```

## joins vs includes — Reminder

```ruby
# joins: INNER JOIN for filtering. Does NOT preload association.
posts = Post.joins(:comments).where(comments: { approved: true }).distinct
posts.first.comments  # Triggers ANOTHER query!

# includes: Eager load for access. Separate queries by default.
posts = Post.includes(:comments)
posts.first.comments  # No additional query

# If you need BOTH filtering AND eager loading:
posts = Post.eager_load(:comments).where(comments: { approved: true })
# Single LEFT OUTER JOIN, and comments are preloaded
```

---

## Eager Loading — Deep Dive

### includes (Auto Strategy)

```ruby
# Single association
Post.includes(:author)

# Multiple
Post.includes(:author, :comments)

# Nested
Post.includes(comments: :author)

# Deep nesting
Post.includes(comments: { author: :profile })

# Mixed
Post.includes(:tags, comments: :author)
```

Rails decides the strategy:
- **Default:** Separate queries (`SELECT * FROM posts`, then `SELECT * FROM authors WHERE id IN (...)`)
- **With where on association:** Switches to LEFT OUTER JOIN automatically

```ruby
# This forces a JOIN strategy because of the where on comments
Post.includes(:comments).where(comments: { approved: true })

# For string conditions, you must add references
Post.includes(:comments).where("comments.approved = ?", true).references(:comments)
```

### preload (Force Separate Queries)

```ruby
Post.preload(:comments)
# Always: SELECT * FROM posts; SELECT * FROM comments WHERE post_id IN (...)
```

**When to use over includes:**
- When `includes` incorrectly switches to JOIN strategy
- When you want predictable query plans
- When the association table is very large (JOINs can be slower than IN queries)

**Cannot** filter on the preloaded association (no `where(comments: {...})` — use `eager_load` for that).

### eager_load (Force Single JOIN)

```ruby
Post.eager_load(:comments)
# Always: SELECT posts.*, comments.* FROM posts LEFT OUTER JOIN comments ON ...
```

**When to use:**
- When you need to filter/order by the association AND preload it
- When a single query is faster than two (rare — test with EXPLAIN)

### strict_loading — Catch Lazy Loading

```ruby
# On a relation
users = User.strict_loading.all
users.first.posts  # Raises ActiveRecord::StrictLoadingViolationError!

# On a record
user = User.first
user.strict_loading!
user.posts  # Raises!

# N+1 only mode — allows belongs_to, catches has_many lazy loads
user.strict_loading!(mode: :n_plus_one_only)
user.profile      # OK (belongs_to, single record)
user.posts         # Raises! (has_many would cause N+1)
user.posts.first.likes  # Raises!

# On an association declaration
class Author < ApplicationRecord
  has_many :books, strict_loading: true
end

# App-wide config
config.active_record.strict_loading_by_default = true
config.active_record.action_on_strict_loading_violation = :log  # or :raise (default)
```

**Recommendation:** Enable `strict_loading` in development/test to catch N+1s early. Use `:log` mode in production if you're not confident in full coverage.
