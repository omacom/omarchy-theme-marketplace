# Finder Methods, Where Conditions, Ordering, Select, and Pluck

## Finder Methods In Depth

### find — By Primary Key

```ruby
# Single record — raises ActiveRecord::RecordNotFound if missing
user = User.find(42)

# Multiple records — raises if ANY id is missing
users = User.find([1, 2, 3])
users = User.find(1, 2, 3)  # Same thing

# Composite primary keys
record = Model.find([store_id, id])
records = Model.find([[1, 8], [7, 15]])
```

**When to use:** You have an ID and the record MUST exist. Controller show/edit/update/destroy actions.

### find_by — By Attributes

```ruby
user = User.find_by(email: "alice@example.com")        # nil if not found
user = User.find_by!(email: "alice@example.com")       # raises if not found

# Multiple conditions
user = User.find_by(email: "alice@example.com", active: true)
```

**When to use:** Looking up by non-PK attributes. Use bang version when missing record is an error.

**Gotcha:** `find_by` does NOT guarantee order. If multiple records match, you get an arbitrary one. Add `.order(...)` before if you need deterministic results:

```ruby
# Deterministic
User.order(:created_at).find_by(role: :admin)
```

### first / last / take

```ruby
User.first              # ORDER BY id ASC LIMIT 1
User.last               # ORDER BY id DESC LIMIT 1
User.take               # LIMIT 1 (no ORDER — database decides)

User.first(5)           # First 5 records
User.last(3)            # Last 3 records

# With scopes
User.where(active: true).first   # First active user by PK
User.order(:name).first           # First alphabetically

# Bang versions — raise if no records
User.first!
User.last!
User.take!
```

### find_or_create_by / find_or_initialize_by

```ruby
# Creates if not found (runs validations — may return unsaved record)
user = User.find_or_create_by(email: "new@example.com")

# Bang version — raises on validation failure
user = User.find_or_create_by!(email: "new@example.com")

# With additional attributes for creation only
user = User.find_or_create_by(email: "new@example.com") do |u|
  u.name = "New User"
  u.role = :member
end

# Or with create_with
user = User.create_with(name: "New User", role: :member)
            .find_or_create_by(email: "new@example.com")

# Initialize without saving (like .new)
user = User.find_or_initialize_by(email: "maybe@example.com")
user.persisted?   # false if it was just built
user.new_record?  # true if it was just built
user.save         # Save when ready
```

**Race condition warning:** `find_or_create_by` is NOT atomic. Two concurrent requests can both fail the `find`, then both `create`. Add a unique index + rescue:

```ruby
User.find_or_create_by(email: "x@y.com")
rescue ActiveRecord::RecordNotUnique
  retry
end
```

---

## Where Conditions — Full Reference

### Hash Conditions

```ruby
# Equality
Book.where(title: "Dune")

# IN (array)
Book.where(id: [1, 2, 3])

# Range (BETWEEN)
Book.where(price: 10..50)

# Beginless range (<=)
Book.where(price: ..50)

# Endless range (>=)
Book.where(price: 10..)

# NULL
Book.where(deleted_at: nil)

# Boolean
Book.where(published: true)

# Association object
Book.where(author: author_instance)

# Nested hash (on joined/included tables)
Book.joins(:author).where(authors: { name: "Frank Herbert" })
```

### NOT Conditions

```ruby
Book.where.not(out_of_print: true)
Book.where.not(id: [1, 2, 3])    # NOT IN
Book.where.not(deleted_at: nil)   # IS NOT NULL
```

**Gotcha with nullable columns:**
```ruby
# If nullable_country is NULL for some records:
Customer.where.not(nullable_country: "UK")
# Does NOT return records where nullable_country IS NULL!
# NULL != "UK" evaluates to NULL (unknown), not true

# To include NULLs:
Customer.where.not(nullable_country: "UK").or(Customer.where(nullable_country: nil))
```

### OR Conditions

```ruby
User.where(role: :admin).or(User.where(role: :moderator))
# WHERE role = 'admin' OR role = 'moderator'

# Often cleaner with IN:
User.where(role: [:admin, :moderator])
```

### AND Conditions

```ruby
# Implicit AND — just chain where
User.where(active: true).where(verified: true)

# Explicit AND (for intersecting separate relations)
admins = User.where(role: :admin)
verified = User.where(verified: true)
admins.and(verified)
```

### String Conditions

```ruby
# Positional parameters
Book.where("price > ? AND price < ?", 10, 50)

# Named parameters
Book.where("price > :min AND price < :max", min: 10, max: 50)

# LIKE with sanitization
Book.where("title LIKE ?", "#{Book.sanitize_sql_like(query)}%")

# ILIKE (PostgreSQL case-insensitive)
Book.where("title ILIKE ?", "%#{Book.sanitize_sql_like(query)}%")
```

### Tuple Conditions (Composite Keys)

```ruby
Book.where([:author_id, :id] => [[15, 1], [15, 2]])
# WHERE (author_id = 15 AND id = 1) OR (author_id = 15 AND id = 2)
```

---

## Ordering

```ruby
# Symbol (ascending by default)
Book.order(:title)

# Hash (explicit direction)
Book.order(title: :asc)
Book.order(created_at: :desc)

# Multiple columns
Book.order(title: :asc, created_at: :desc)

# String (for complex expressions)
Book.order("LOWER(title) ASC")
Book.order(Arel.sql("FIELD(status, 'active', 'pending', 'archived')"))

# From joined tables
Book.includes(:author).order("authors.name ASC")
Book.includes(:author).order(authors: { name: :asc })

# Override previous order
Book.order(:title).reorder(:created_at)   # Only created_at

# Reverse
Book.order(:title).reverse_order          # title DESC

# Append
Book.order(:title).order(:created_at)     # title ASC, created_at ASC
```

**Important:** `order` with string args and `Arel.sql` can be SQL injection vectors if you interpolate user input. Always use hash syntax or whitelisting.

---

## Select and Pluck

### select — Returns AR Objects with Limited Attributes

```ruby
# Only load specific columns
Book.select(:id, :title)
Book.select("id, title")

# Computed columns
Book.select("title, LENGTH(title) AS title_length")
book.title_length  # Accessible as an attribute

# Distinct
Customer.select(:last_name).distinct
```

**Gotcha:** Accessing unselected columns raises `ActiveModel::MissingAttributeError`:
```ruby
book = Book.select(:title).first
book.isbn  # MissingAttributeError!
```

### reselect — Override Previous Select

```ruby
Book.select(:title, :isbn).reselect(:created_at)
# SELECT books.created_at FROM books
```

### pluck — Returns Raw Arrays

```ruby
Book.pluck(:title)                    # ["Dune", "1984", ...]
Book.pluck(:id, :title)              # [[1, "Dune"], [2, "1984"], ...]
Book.where(published: true).pluck(:id)

# From joined tables
Order.joins(:customer).pluck("orders.id, customers.email")
```

**Key differences from select:**
- `pluck` returns plain Ruby arrays, NOT AR objects
- `pluck` triggers the query immediately (can't chain further)
- `pluck` is significantly faster for extracting data
- `pluck` skips model instantiation and callbacks

```ruby
# DO: pluck then chain Ruby methods
ids = User.where(active: true).pluck(:id)

# DON'T: pluck then try to chain AR methods
User.pluck(:id).where(active: true)  # NoMethodError! pluck returns Array
```

### pick — Single Value

```ruby
User.where(id: 1).pick(:email)            # "alice@example.com"
User.where(id: 1).pick(:first_name, :last_name)  # ["Alice", "Smith"]
# Equivalent to: .limit(1).pluck(:email).first
```

### ids — Shorthand for pluck(:id)

```ruby
User.where(active: true).ids  # [1, 4, 7, 12]
```

---

## Enums — Query Patterns

### Declaration

```ruby
class Order < ApplicationRecord
  # Hash syntax (recommended — explicit integer mapping)
  enum :status, { pending: 0, processing: 1, shipped: 2, delivered: 3, cancelled: 4 }

  # Array syntax (integers assigned by position — fragile!)
  enum :status, [:pending, :processing, :shipped, :delivered, :cancelled]

  # With prefix/suffix to avoid method name collisions
  enum :status, { active: 0, archived: 1 }, prefix: true
  # Methods: status_active?, status_archived?, status_active!, etc.

  enum :role, { admin: 0, user: 1 }, suffix: :type
  # Methods: admin_type?, user_type?
end
```

### Querying

```ruby
Order.pending                    # Scope: WHERE status = 0
Order.not_pending                # Scope: WHERE status != 0
Order.where(status: :shipped)    # Explicit
Order.where(status: [:shipped, :delivered])  # Multiple values

order.shipped?                   # Check
order.shipped!                   # Set + save!
```

### Gotcha: Don't Reorder Enum Arrays

```ruby
# If you had:
enum :status, [:pending, :shipped, :delivered]

# And later insert :processing:
enum :status, [:pending, :processing, :shipped, :delivered]
# shipped is now 2 (was 1), delivered is now 3 (was 2)
# ALL EXISTING DATA IS WRONG

# Always use hash syntax to avoid this:
enum :status, { pending: 0, shipped: 1, delivered: 2 }
# Safe to add: processing: 3
```
