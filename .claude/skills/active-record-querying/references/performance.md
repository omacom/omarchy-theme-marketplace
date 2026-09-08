# Performance Patterns and Rails 8.1 Features

## Avoiding SELECT *

```ruby
# When you only need specific columns (e.g., for a dropdown)
User.select(:id, :name).order(:name)

# Even better if you don't need AR objects
User.order(:name).pluck(:id, :name)
# => [[1, "Alice"], [2, "Bob"]]
```

## Subqueries

```ruby
# Use subqueries to avoid loading intermediate results
active_user_ids = User.where(active: true).select(:id)
Post.where(user_id: active_user_ids)
# SELECT posts.* FROM posts WHERE user_id IN (SELECT id FROM users WHERE active = true)
# Note: Rails automatically makes this a subquery — no .pluck needed!
```

## update_all / delete_all (Bulk Operations)

```ruby
# Skip callbacks and validations — direct SQL
User.where(active: false).update_all(archived: true)
User.where("last_login < ?", 2.years.ago).delete_all

# With increment/decrement
Post.where(id: post_ids).update_all("view_count = view_count + 1")
```

## Caching with size

```ruby
users = User.where(active: true)

# .count always runs SELECT COUNT(*)
users.count  # Query
users.count  # Query again

# .size is smart
users.size   # SELECT COUNT(*) (not loaded yet)
users.to_a   # Loads records
users.size   # No query (uses loaded array length)

# .length always loads records
users.length # Loads ALL records, counts in Ruby
```

## Explain Your Queries

```ruby
# Basic explain
User.where(email: "x@y.com").explain

# With analysis (PostgreSQL)
User.where(email: "x@y.com").explain(:analyze, :verbose)

# MySQL/MariaDB
User.where(email: "x@y.com").explain(:analyze)
```

---

## Rails 8.1 Features

### normalizes (Attribute Normalization)

While not strictly a query feature, `normalizes` affects how data is stored and therefore queried:

```ruby
class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }
end

# Queries automatically apply normalization
User.where(email: "  Alice@Example.COM  ")
# Matches records with email "alice@example.com"
User.find_by(email: "  Alice@Example.COM  ")
# Correctly finds the user
```

### Composite Primary Keys

```ruby
class TravelRoute < ApplicationRecord
  self.primary_key = [:origin, :destination]
end

route = TravelRoute.find(["Chicago", "NYC"])
routes = TravelRoute.find([["Chicago", "NYC"], ["NYC", "LA"]])
```

### where.associated / where.missing (Added Rails 7, Stable in 8.1)

```ruby
# Cleaner than LEFT JOIN + WHERE NULL checks
Customer.where.associated(:orders)    # Has at least one order
Customer.where.missing(:orders)       # Has no orders
```

### assert_queries_count (Testing)

```ruby
# Assert exact query count
assert_queries_count(2) do
  User.includes(:posts).first.posts.to_a
end

# Assert no queries (e.g., cached data)
assert_no_queries do
  @cached_user.name
end
```

---

## Index of All Query Methods

**Finders:** `find`, `find_by`, `find_by!`, `first`, `first!`, `last`, `last!`, `take`, `take!`, `find_or_create_by`, `find_or_create_by!`, `find_or_initialize_by`, `find_by_sql`

**Conditions:** `where`, `where.not`, `where.associated`, `where.missing`, `or`, `and`, `rewhere`

**Ordering:** `order`, `reorder`, `reverse_order`

**Limiting:** `limit`, `offset`

**Selecting:** `select`, `reselect`, `distinct`

**Grouping:** `group`, `regroup`, `having`

**Joins:** `joins`, `left_outer_joins`, `includes`, `preload`, `eager_load`

**Eager Loading:** `includes`, `preload`, `eager_load`, `strict_loading`, `extract_associated`

**Scoping:** `scope`, `default_scope`, `unscoped`, `unscope`, `only`, `merge`

**Batching:** `find_each`, `find_in_batches`, `in_batches`

**Calculations:** `count`, `sum`, `average`, `minimum`, `maximum`, `pluck`, `pick`, `ids`

**Existence:** `exists?`, `any?`, `many?`, `none?`

**Mutation:** `update_all`, `delete_all`, `destroy_all`, `touch_all`

**Locking:** `lock`, `with_lock`

**Other:** `none`, `readonly`, `extending`, `annotate`, `optimizer_hints`, `create_with`, `from`, `explain`
