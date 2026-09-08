# Grouping, Aggregations, Existence, and Calculations

## Grouping and Aggregations

### group

```ruby
# Count per status
Order.group(:status).count
# => {"pending" => 5, "shipped" => 12, "delivered" => 8}

# Sum per category
Product.group(:category).sum(:price)

# Group by date
Order.group("DATE(created_at)").count

# Multiple groups
Order.group(:status, :payment_method).count
# => {["pending", "card"] => 3, ["shipped", "card"] => 7, ...}
```

### having

```ruby
# Filter groups
Author.joins(:books).group("authors.id")
  .having("COUNT(books.id) > ?", 5)
  .select("authors.*, COUNT(books.id) AS book_count")

# With aggregation
Order.group(:customer_id)
  .having("SUM(total) > ?", 1000)
  .sum(:total)
```

### regroup — Override Previous Group

```ruby
Book.group(:author).regroup(:id)
# GROUP BY id (not author)
```

---

## Existence Checks

| Method | SQL | When to use |
|--------|-----|-------------|
| `exists?` | `SELECT 1 ... LIMIT 1` | Always prefer for existence checks |
| `exists?(id)` | `SELECT 1 WHERE id = ? LIMIT 1` | Check specific record by PK |
| `any?` | `SELECT 1 ... LIMIT 1` | Same as exists? on relations |
| `none?` | `SELECT 1 ... LIMIT 1` | Inverse of any? |
| `many?` | `SELECT COUNT(*) FROM (... LIMIT 2)` | More than one? |
| `present?` | Loads relation! | **Avoid** — use exists? |
| `empty?` | `SELECT 1 ... LIMIT 1` | OK — similar to !any? |

```ruby
# All valid
User.exists?(42)
User.where(active: true).exists?
User.any?
User.where(role: :admin).many?
order.line_items.any?
```

---

## Calculations

```ruby
Order.count                           # COUNT(*)
Order.count(:discount)                # COUNT(discount) — excludes NULL
Order.where(status: :shipped).count

Order.sum(:total)
Order.average(:total)
Order.minimum(:total)
Order.maximum(:total)

# With group
Order.group(:status).count            # => {"shipped" => 12, "pending" => 5}
Order.group(:status).sum(:total)      # => {"shipped" => 5000, "pending" => 1200}
Order.group(:status).average(:total)

# Distinct count
Order.distinct.count(:customer_id)    # Number of unique customers who ordered
```

---

## Locking

### Optimistic Locking

```ruby
# Requires lock_version integer column
c1 = Customer.find(1)
c2 = Customer.find(1)

c1.name = "Sandra"
c1.save!

c2.name = "Michael"
c2.save!  # Raises ActiveRecord::StaleObjectError
```

### Pessimistic Locking

```ruby
# Row-level lock (FOR UPDATE)
Book.transaction do
  book = Book.lock.find(42)    # SELECT ... FOR UPDATE
  book.stock -= 1
  book.save!
end

# Lock existing instance
book = Book.first
book.with_lock do
  book.increment!(:views)
end

# Share lock (PostgreSQL/MySQL)
Book.transaction do
  book = Book.lock("FOR SHARE").find(42)
  # Other transactions can read but not modify
end
```
