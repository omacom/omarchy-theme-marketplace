# DB Constraints, Uniqueness Race Conditions, and Numericality Edge Cases

Pairing model validations with database constraints, handling race conditions, and numericality gotchas.

## Uniqueness Race Conditions

### The problem

```
Request A:  SELECT COUNT(*) WHERE email = 'foo@bar.com'  →  0
Request B:  SELECT COUNT(*) WHERE email = 'foo@bar.com'  →  0
Request A:  INSERT INTO users (email) VALUES ('foo@bar.com')  →  ✓
Request B:  INSERT INTO users (email) VALUES ('foo@bar.com')  →  ✓  DUPLICATE!
```

### The solution: DB unique index + rescue

```ruby
# Migration:
add_index :users, :email, unique: true

# Model:
validates :email, uniqueness: true  # still useful for nice error messages

# Controller — handle the race condition:
def create
  @user = User.new(user_params)
  @user.save!
  redirect_to @user
rescue ActiveRecord::RecordNotUnique
  @user.errors.add(:email, :taken)
  render :new, status: :unprocessable_entity
end
```

### Scoped uniqueness

```ruby
# Model:
validates :slug, uniqueness: { scope: :blog_id }

# Migration — composite unique index:
add_index :posts, [:blog_id, :slug], unique: true
```

### Soft-delete aware uniqueness

```ruby
# Model:
validates :email, uniqueness: { conditions: -> { where(deleted_at: nil) } }

# Migration (PostgreSQL partial index):
add_index :users, :email, unique: true, where: "deleted_at IS NULL"
```

### Multi-tenant uniqueness

```ruby
# With acts_as_tenant or manual scoping:
validates :name, uniqueness: { scope: :tenant_id }

# DB index must match:
add_index :projects, [:tenant_id, :name], unique: true
```

---

## DB Constraint Pairing Patterns

### Complete model + migration examples

```ruby
# Model:
class Product < ApplicationRecord
  normalizes :sku, with: ->(sku) { sku.strip.upcase }

  validates :name, presence: true, length: { maximum: 255 }
  validates :sku, presence: true, uniqueness: true, format: { with: /\A[A-Z0-9\-]+\z/ }
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :category, inclusion: { in: %w[electronics clothing food] }
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
end

# Migration:
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false, limit: 255
      t.string :sku, null: false
      t.integer :price_cents, null: false
      t.string :category, null: false
      t.decimal :weight_kg, precision: 8, scale: 2
      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_check_constraint :products, "price_cents > 0", name: "products_price_positive"
    add_check_constraint :products, "category IN ('electronics', 'clothing', 'food')", name: "products_category_valid"
  end
end
```

### PostgreSQL CHECK constraints

```ruby
# In migration:
add_check_constraint :orders, "total_cents >= 0", name: "orders_total_non_negative"
add_check_constraint :events, "end_date > start_date", name: "events_date_range_valid"
add_check_constraint :users, "age >= 0 AND age <= 150", name: "users_age_reasonable"

# Remove:
remove_check_constraint :orders, name: "orders_total_non_negative"
```

---

## Numericality Edge Cases

### nil handling

```ruby
# Rejects nil by default:
validates :age, numericality: true
User.new(age: nil).valid?  # => false

# Allow nil:
validates :age, numericality: { allow_nil: true }
```

### Empty string conversion

On `integer` and `float` columns, Active Record converts `""` to `nil` before validation.

```ruby
# Column: t.integer :age
user.age = ""
user.age  # => nil (Active Record type cast)
# Then numericality rejects nil unless allow_nil: true
```

### Float precision

```ruby
validates :price, numericality: { greater_than: 0 }

# Be careful with float comparisons:
(0.1 + 0.2) == 0.3  # => false in Ruby!

# For money, use decimal columns:
# t.decimal :price, precision: 10, scale: 2
# Or store as integer cents and validate that
```

### Combining constraints

```ruby
validates :score, numericality: {
  only_integer: true,
  greater_than_or_equal_to: 0,
  less_than_or_equal_to: 100
}

# Equivalent with :in (Rails 7+):
validates :score, numericality: { only_integer: true, in: 0..100 }
```
