---
name: active-record-querying
description: Expert guidance for writing efficient, correct Active Record queries in Rails 8.1. Use when writing queries, finding records, building scopes, fixing N+1 queries, using where clauses, includes, joins, eager loading, filtering, searching, plucking data, selecting records, or optimizing database queries. Covers where, find, scopes, includes vs preload vs eager_load, joins, pluck, select, calculations, batching, and query anti-patterns.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails console), Bash(bin/rails runner)
---

# Active Record Querying Expert

Write efficient, correct, and maintainable Active Record queries. Avoid N+1s, unnecessary memory allocation, and query anti-patterns.

## Philosophy

1. **Let the database do the work** — Filter, sort, count, and aggregate in SQL, not Ruby
2. **Load only what you need** — Don't `SELECT *` when you need one column
3. **Prevent N+1 by default** — Always think about associations before iterating
4. **Scopes over ad-hoc queries** — Named, composable, testable
5. **Fail loudly** — Use bang methods when a missing record is a bug

## Decision Trees

### Finding a Single Record

```
Need a record by primary key?
  → find(id)                    # Raises if not found — this is usually what you want
  → find_by(id: id)             # Returns nil if not found

Need a record by attributes?
  → find_by(email: "x@y.com")  # Returns nil — good for "maybe exists" cases
  → find_by!(email: "x@y.com") # Raises — good for "must exist" cases

Avoid:
  → where(email: "x").first    # Unnecessary — find_by does this in one step
  → where(email: "x").take     # Same thing, less clear intent
```

### Loading Associations (N+1 Prevention)

```
Do you need associated data while iterating?
  YES → Use eager loading (see below)
  NO  → Don't eager load — it wastes memory

Which eager loading method?
  includes   → DEFAULT CHOICE. Rails picks best strategy (2 queries or JOIN)
  preload    → FORCE separate queries. Use when includes picks wrong strategy
  eager_load → FORCE single LEFT OUTER JOIN. Use when you need to filter on association
```

**The includes/preload/eager_load decision:**

| Method | Strategy | When to use |
|--------|----------|-------------|
| `includes` | Auto (usually 2 queries) | **Default.** Handles most cases correctly |
| `preload` | Always separate queries | When `includes` incorrectly uses a JOIN, or you want predictable query count |
| `eager_load` | Always LEFT OUTER JOIN | When you need `where` conditions on the association |
| `joins` | INNER JOIN (no loading) | When you need to filter but DON'T need the associated objects |

```ruby
# GOOD — includes handles this with 2 queries
posts = Post.includes(:comments).where(published: true)

# GOOD — eager_load when filtering on association
posts = Post.eager_load(:comments).where(comments: { approved: true })

# GOOD — joins when you filter but don't use the association data
posts = Post.joins(:comments).where(comments: { approved: true }).distinct

# BAD — this loads ALL comments into memory just to check existence
posts = Post.all.select { |p| p.comments.any? }

# GOOD — let the DB check existence
posts = Post.where.associated(:comments)
```

### Checking Existence

```ruby
# GOOD — single SELECT 1 ... LIMIT 1 query
User.exists?(email: "x@y.com")
User.where(active: true).exists?

# OK — but slightly slower (loads the relation first if not already loaded)
User.where(active: true).any?

# BAD — loads ALL records into Ruby, then checks (wastes memory + time)
User.where(active: true).present?
User.where(active: true).to_a.any?

# BAD — count scans the full result set; exists? stops at the first match
User.where(active: true).count > 0  # Use exists? instead
```

**Rule:** `exists?` > `any?` > `present?` > `count > 0`

### Getting Data Out

```
Need Ruby objects with methods/callbacks?
  → Use where/find/select (returns AR objects)

Need raw values for display, export, or IDs?
  → Use pluck (returns arrays, skips AR instantiation)

Need a single value?
  → Use pick (like pluck but returns one value)

Need to count/sum/average?
  → Use count/sum/average/minimum/maximum (SQL aggregates)
```

```ruby
# GOOD — pluck for raw values (fast, low memory)
user_ids = User.where(active: true).pluck(:id)
emails = User.where(role: :admin).pluck(:email)
pairs = User.pluck(:id, :email)  # => [[1, "a@b.com"], [2, "c@d.com"]]

# GOOD — pick for a single value
User.where(id: 1).pick(:email)  # => "a@b.com"

# BAD — instantiates full AR objects just to extract one field
User.where(active: true).map(&:id)        # Use pluck(:id)
User.where(active: true).select(:id).map(&:id)  # Still slower than pluck

# GOOD — ids shorthand
User.where(active: true).ids  # Same as pluck(:id) but reads better

# GOOD — SQL aggregates
Order.where(status: :complete).sum(:total)
Order.average(:total)
Product.maximum(:price)
```

## Scopes

### When to Use Scopes vs Class Methods

**Use scopes for:**
- Simple, composable query fragments
- Conditions you chain frequently
- Queries that should ALWAYS return a relation (never nil)

**Use class methods for:**
- Complex queries with conditional logic
- Queries that might return nil (class method nil = no scope applied; scope nil = `.all`)
- Queries that need multiple statements

```ruby
class Post < ApplicationRecord
  # GOOD — clean, composable scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_author, ->(author) { where(author: author) }
  scope :popular, -> { where("view_count > ?", 100) }

  # GOOD — class method for conditional logic
  def self.search(query)
    return all if query.blank?  # Return all, not nil!
    where("title ILIKE ?", "%#{sanitize_sql_like(query)}%")
  end

  # BAD — scope with conditional that returns nil
  # If time is nil, this returns nil → breaks chaining
  scope :created_before, ->(time) { where(created_at: ...time) if time.present? }
  # Actually this is OK in scopes (Rails auto-converts nil → all)
  # But it's confusing. Prefer explicit:
  scope :created_before, ->(time) { time.present? ? where(created_at: ...time) : all }
end

# Compose freely
Post.published.recent.by_author(user).limit(10)
```

### Scope Anti-Patterns

```ruby
# BAD — default_scope is almost always a mistake
class Post < ApplicationRecord
  default_scope { where(deleted: false) }  # Infects EVERY query, including joins
end

# BAD — overly broad scope name
scope :active, -> { where(active: true).where(verified: true).where("last_login > ?", 30.days.ago) }
# Better: break into composable pieces
scope :active, -> { where(active: true) }
scope :verified, -> { where(verified: true) }
scope :recently_active, -> { where("last_login > ?", 30.days.ago) }
```

## Batching Large Datasets

**Iterate large tables in batches** — `.each` on an unbounded relation loads the entire result set into memory at once:

```ruby
# BAD — loads entire table into memory
User.all.each { |u| u.send_newsletter }

# GOOD — processes in batches of 1000 (default)
User.find_each { |u| u.send_newsletter }

# GOOD — custom batch size
User.find_each(batch_size: 500) { |u| u.send_newsletter }

# GOOD — when you need the batch as an array
User.find_in_batches(batch_size: 1000) do |batch|
  SomeService.bulk_process(batch)
end

# GOOD — when you need an ActiveRecord::Relation per batch (Rails 5+)
User.in_batches(of: 1000) do |batch_relation|
  batch_relation.update_all(processed: true)  # Single UPDATE query per batch
end
```

**Batching methods:**
- `find_each` — yields individual records. Most common.
- `find_in_batches` — yields arrays of records. For bulk operations on objects.
- `in_batches` — yields Relations. For bulk SQL operations (update_all, delete_all).
- All three sort by primary key internally. They can't be combined with custom `.order()` because batching relies on PK ordering to paginate.

## Joins

### joins vs includes — Know the Difference

```ruby
# joins = INNER JOIN, for FILTERING. Does NOT load association.
Post.joins(:comments).where(comments: { approved: true }).distinct
# Use: "Give me posts that HAVE approved comments"
# The comments are NOT loaded — accessing post.comments triggers another query!

# includes = eager loading, for USING associations. Prevents N+1.
Post.includes(:comments).where(published: true)
# Use: "Give me posts AND their comments, because I'll display them"

# Common mistake: using joins thinking it loads the association
posts = Post.joins(:author).limit(10)
posts.each { |p| p.author.name }  # N+1! joins doesn't eager load!

# Fix:
posts = Post.includes(:author).limit(10)
posts.each { |p| p.author.name }  # No N+1
```

### left_outer_joins

```ruby
# Include ALL records, even without the association
Customer.left_outer_joins(:orders)
  .select("customers.*, COUNT(orders.id) AS orders_count")
  .group("customers.id")

# Cleaner: find records WITH or WITHOUT associations
Customer.where.associated(:orders)    # Has orders (INNER JOIN + NOT NULL)
Customer.where.missing(:orders)       # No orders (LEFT JOIN + IS NULL)
```

## Where Conditions

### Hash Conditions (Preferred)

```ruby
# Equality
User.where(active: true)

# IN
User.where(role: [:admin, :moderator])

# Range (BETWEEN)
Order.where(created_at: 1.week.ago..Time.current)

# Greater/less than (endless/beginless ranges)
Order.where(total: 100..)    # total >= 100
Order.where(total: ..100)    # total <= 100

# Nil
User.where(deleted_at: nil)  # IS NULL

# NOT
User.where.not(role: :banned)
User.where.not(deleted_at: nil)  # IS NOT NULL

# OR
User.where(role: :admin).or(User.where(role: :moderator))

# Association conditions
Post.where(author: { active: true })  # Only with joins/includes
```

### String Conditions (When Hash Won't Work)

```ruby
# ALWAYS use parameterized queries — never interpolate user input
User.where("email LIKE ?", "%#{User.sanitize_sql_like(query)}%")
User.where("created_at > :date", date: 1.week.ago)

# NEVER do this — SQL injection lets attackers read/modify your entire database
User.where("email = '#{params[:email]}'")  # VULNERABLE!
```

## Raw SQL

### When It's OK

- Complex queries that AR can't express cleanly
- Performance-critical queries where you need specific SQL
- Reporting/analytics queries with complex aggregations

### How to Do It Safely

```ruby
# GOOD — parameterized
User.where("age > ? AND city = ?", 18, "NYC")

# GOOD — named parameters
User.where("age > :min_age AND city = :city", min_age: 18, city: "NYC")

# GOOD — sanitize for LIKE
User.where("name LIKE ?", "#{User.sanitize_sql_like(query)}%")

# GOOD — find_by_sql for fully custom queries
results = User.find_by_sql([
  "SELECT users.*, COUNT(orders.id) as order_count
   FROM users LEFT JOIN orders ON orders.user_id = users.id
   WHERE users.active = ?
   GROUP BY users.id
   HAVING COUNT(orders.id) > ?",
  true, 5
])

# GOOD — select_all for raw hashes (no AR objects)
result = ActiveRecord::Base.lease_connection.select_all(
  "SELECT DATE(created_at) as day, COUNT(*) as total FROM orders GROUP BY day"
)
result.to_a  # => [{"day" => "2025-01-01", "total" => 42}, ...]

# GOOD — Arel for complex programmatic query building
users = User.arel_table
User.where(users[:age].gt(18).and(users[:city].eq("NYC")))
```

## Enums

```ruby
class Order < ApplicationRecord
  enum :status, { pending: 0, processing: 1, shipped: 2, delivered: 3, cancelled: 4 }
end

# Auto-generated scopes
Order.pending          # WHERE status = 0
Order.not_pending      # WHERE status != 0
Order.shipped          # WHERE status = 2

# Check and set
order.pending?         # true/false
order.shipped!         # UPDATE ... SET status = 2

# Query with symbol (preferred)
Order.where(status: :shipped)
Order.where(status: [:shipped, :delivered])

# Avoid raw integers — if enum values shift, queries silently break
Order.where(status: 2)  # Use the symbol instead
```

## Common Anti-Patterns

### 1. Loading Everything Into Memory

```ruby
# BAD
User.all.select { |u| u.active? }     # Loads ALL users, filters in Ruby
User.all.count                          # .all is redundant, and forces load if cached

# GOOD
User.where(active: true)               # SQL filter
User.count                              # SQL COUNT
```

### 2. N+1 Queries

```ruby
# BAD — 1 query for posts + N queries for authors
Post.limit(10).each { |p| puts p.author.name }

# GOOD
Post.includes(:author).limit(10).each { |p| puts p.author.name }
```

### 3. Unnecessary Eager Loading

```ruby
# BAD — loads ALL associations when you only need the post
Post.includes(:comments, :tags, :author).find(1)
# (If you only display the post title, this wastes memory)

# GOOD — only eager load what you'll use
Post.find(1)  # If you just need the post
Post.includes(:author).find(1)  # If you'll display author too
```

### 4. Using map Where pluck Works

```ruby
# BAD
User.where(active: true).map(&:email)   # Instantiates AR objects
User.select(:email).map(&:email)         # Still instantiates objects

# GOOD
User.where(active: true).pluck(:email)   # Returns plain strings
```

### 5. count vs size vs length

```ruby
relation = User.where(active: true)

relation.count   # ALWAYS hits DB with COUNT query
relation.length  # Loads ALL records, counts in Ruby (bad if not already loaded)
relation.size    # Smart: uses count if not loaded, length if already loaded

# Rule: use .size on relations, .count when you need a fresh DB count
```

### 6. Forgetting distinct with joins

```ruby
# BAD — returns duplicate posts (one per comment)
Post.joins(:comments).where(comments: { approved: true })

# GOOD
Post.joins(:comments).where(comments: { approved: true }).distinct
```

## Query Debugging

```ruby
# See the SQL a relation will generate
puts User.where(active: true).to_sql

# See the explain plan
puts User.where(active: true).explain

# In console — enable query logging
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Count queries in a block (tests)
assert_queries_count(2) { User.includes(:posts).first.posts.to_a }
assert_no_queries { cached_result }
```

## Quick Reference: Method Cheat Sheet

| Want to... | Use | Returns |
|------------|-----|---------|
| Find by PK (must exist) | `find(id)` | Record or raises |
| Find by PK (might not exist) | `find_by(id: id)` | Record or nil |
| Find by attributes | `find_by(email: "x")` | Record or nil |
| Find by attributes (must exist) | `find_by!(email: "x")` | Record or raises |
| Filter records | `where(active: true)` | Relation |
| Exclude records | `where.not(role: :banned)` | Relation |
| Has association | `where.associated(:orders)` | Relation |
| Missing association | `where.missing(:orders)` | Relation |
| Sort | `order(created_at: :desc)` | Relation |
| Limit | `limit(10)` | Relation |
| Offset | `offset(20)` | Relation |
| Distinct | `distinct` | Relation |
| Raw values | `pluck(:email)` | Array |
| Single raw value | `pick(:email)` | Value |
| All IDs | `ids` | Array |
| Count | `count` | Integer |
| Exists? | `exists?(email: "x")` | Boolean |
| Group | `group(:status).count` | Hash |
| Sum/Avg/Min/Max | `sum(:total)` | Numeric |
| Eager load (auto) | `includes(:author)` | Relation |
| Eager load (separate queries) | `preload(:author)` | Relation |
| Eager load (single JOIN) | `eager_load(:author)` | Relation |
| INNER JOIN (filter only) | `joins(:author)` | Relation |
| LEFT JOIN | `left_outer_joins(:orders)` | Relation |
| Batch iterate | `find_each` | yields records |
| Batch arrays | `find_in_batches` | yields arrays |
| Batch relations | `in_batches` | yields Relations |
| Find or create | `find_or_create_by(name: "x")` | Record |
| Find or init | `find_or_initialize_by(name: "x")` | Record (maybe unsaved) |

For detailed patterns, advanced examples, and edge cases, see the `references/` directory:
- `references/finders.md` — Finder methods, where conditions, ordering, select/pluck, enums
- `references/joins-and-includes.md` — Joins, eager loading (includes/preload/eager_load), strict_loading
- `references/scopes.md` — Scope patterns, overriding conditions, method chaining, query objects
- `references/batching.md` — find_each, find_in_batches, in_batches
- `references/calculations.md` — Grouping, aggregations, existence checks, locking
- `references/raw-sql.md` — Safe raw SQL patterns (find_by_sql, select_all, sanitization)
- `references/performance.md` — Performance patterns, Rails 8.1 features, full method index
