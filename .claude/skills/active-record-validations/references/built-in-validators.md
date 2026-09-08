# Built-in Validators Complete Reference

All built-in Active Record validators with complete options, edge cases, and normalizations.

## absence

Validates the attribute is blank (`nil`, `""`, or whitespace-only string).

```ruby
validates :supplementary_info, absence: true
validates :end_date, absence: true, unless: :multi_day_event?
```

For associations:
```ruby
belongs_to :order, optional: true
validates :order, absence: true  # validate the association object, not foreign key
```

For booleans (since `false.present?` is false):
```ruby
validates :hidden, exclusion: { in: [true, false] }  # truly absent — no true or false
```

Default error: `"must be blank"`

## acceptance

Virtual attribute — no DB column needed unless you explicitly create one.

```ruby
validates :terms_of_service, acceptance: true
validates :eula, acceptance: { accept: ["TRUE", "accepted", "yes"] }
validates :terms, acceptance: { message: "must be agreed to before continuing" }
```

Only runs when the attribute is not `nil`. Default accepts `['1', true]`.

If a DB column exists, the `accept` option must include `true` or the validation won't trigger.

Default error: `"must be accepted"`

## comparison

Compare any two `Comparable` values. Options accept values, procs, or symbols referencing methods.

```ruby
validates :end_date, comparison: { greater_than: :start_date }
validates :age, comparison: { greater_than_or_equal_to: 18 }
validates :weight, comparison: { less_than: 500 }
validates :rating, comparison: { in: 1..5 }  # not documented everywhere but works

# With proc:
validates :renewal_date, comparison: { greater_than: -> { Date.current } }

# With method symbol:
validates :discount_price, comparison: { less_than: :regular_price }
```

All comparison options:
- `:greater_than`
- `:greater_than_or_equal_to`
- `:equal_to`
- `:less_than`
- `:less_than_or_equal_to`
- `:other_than`

Default error: `"failed comparison"` (plus specific messages per option)

## confirmation

Creates a virtual `_confirmation` attribute.

```ruby
class User < ApplicationRecord
  validates :password, confirmation: true
  validates :password_confirmation, presence: true, if: :password_changed?

  # Case-insensitive email confirmation:
  validates :email, confirmation: { case_sensitive: false }
  validates :email_confirmation, presence: true, if: :email_changed?
end
```

**Key detail:** Only validates when the `_confirmation` attribute is not `nil`. Always add `presence: true` on the confirmation field, scoped to when the original field changes.

Default error: `"doesn't match confirmation"`

## exclusion

```ruby
validates :subdomain, exclusion: { in: %w[www admin api mail ftp] }
validates :format, exclusion: { in: %w[exe bat cmd], message: "%{value} is not allowed" }

# Dynamic:
validates :username, exclusion: { in: ->(user) { user.reserved_names } }
```

Uses `include?` for arrays, `cover?` for ranges.

Default error: `"is reserved"`

## format

```ruby
# ALWAYS use \A and \z (string boundaries), NEVER ^ and $ (line boundaries)
validates :username, format: { with: /\A[a-z0-9_]{3,30}\z/i }
validates :legacy_code, format: { with: /\A[A-Z]{3}-\d{4}\z/, message: "must be format XXX-0000" }

# Reject pattern:
validates :content, format: { without: /\b(spam|viagra)\b/i, message: "contains prohibited words" }

# With proc:
validates :code, format: { with: ->(record) { record.code_pattern } }
```

**Security warning:** Using `^` and `$` allows multiline bypass:
```ruby
# VULNERABLE: "valid\n<script>alert('xss')</script>" passes
validates :name, format: { with: /^[a-z]+$/ }

# SAFE:
validates :name, format: { with: /\A[a-z]+\z/ }
```

If you must use `^` or `$`, pass `multiline: true` to acknowledge the risk.

Default error: `"is invalid"`

## inclusion

```ruby
validates :size, inclusion: { in: %w[small medium large] }
validates :priority, inclusion: { in: 1..5 }
validates :role, inclusion: { in: %w[admin editor viewer], message: "%{value} is not a valid role" }

# Dynamic (proc receives the record):
validates :category, inclusion: { in: ->(record) { record.workspace.allowed_categories } }
```

`:within` is an alias for `:in`.

Default error: `"is not included in the list"`

## length

```ruby
validates :name, length: { minimum: 2 }
validates :bio, length: { maximum: 1000 }
validates :password, length: { in: 8..128 }       # range
validates :ssn, length: { is: 9 }                  # exact
validates :title, length: { minimum: 5, maximum: 100 }  # min + max combo

# Custom messages per constraint:
validates :essay, length: {
  minimum: 100,
  too_short: "must have at least %{count} characters",
  maximum: 5000,
  too_long: "must have at most %{count} characters"
}
```

**Gotcha:** When `:minimum` is 1, use `presence: true` instead — better error message.

Default errors: `"is too short (minimum is %{count} characters)"`, `"is too long (maximum is %{count} characters)"`, `"is the wrong length (should be %{count} characters)"`

## numericality

```ruby
validates :price, numericality: true                                    # any number
validates :quantity, numericality: { only_integer: true }               # integers only
validates :score, numericality: { in: 0..100 }                         # range
validates :temperature, numericality: { greater_than: -273.15 }        # absolute zero
validates :discount, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
validates :age, numericality: { only_integer: true, odd: true }        # odd integers
```

All numericality options:
- `:only_integer` — must match `/\A[+-]?\d+\z/`
- `:only_numeric` — must be `Numeric` instance (or parseable string)
- `:greater_than`, `:greater_than_or_equal_to`
- `:equal_to`, `:other_than`
- `:less_than`, `:less_than_or_equal_to`
- `:in` — must be in range
- `:odd`, `:even`

**Edge cases:**
- Rejects `nil` by default — add `allow_nil: true` for optional fields
- Empty strings on `Integer`/`Float` columns get converted to `nil` by Active Record
- Float precision: values are converted through `Float` then `BigDecimal` (max 15 digits precision)
- For money: use `decimal` column with `precision: 10, scale: 2` and validate, or store as integer cents

Default errors: `"is not a number"`, `"must be an integer"`, plus constraint-specific messages

## presence

```ruby
validates :name, presence: true
validates :title, :body, presence: true  # multiple attributes

# For associations — validate the object, not the FK:
belongs_to :author  # already validates presence by default in Rails 5+
has_one :profile
validates :profile, presence: true  # checks object is present, not marked_for_destruction?
```

**Boolean trap:** `false.blank?` returns `true`, so `presence: true` rejects `false`.
```ruby
# WRONG:
validates :active, presence: true  # rejects false!

# RIGHT:
validates :active, inclusion: { in: [true, false] }
```

Default error: `"can't be blank"`

## uniqueness

```ruby
validates :email, uniqueness: true
validates :slug, uniqueness: { scope: :blog_id }           # unique per blog
validates :name, uniqueness: { scope: [:account_id, :year] } # composite scope
validates :code, uniqueness: { case_sensitive: false }
validates :email, uniqueness: { conditions: -> { where(deleted_at: nil) } }  # soft-delete aware
```

**Always back with a DB index:**
```ruby
# Single column:
add_index :users, :email, unique: true

# Scoped:
add_index :posts, [:blog_id, :slug], unique: true

# Partial (PostgreSQL, for soft-delete):
add_index :users, :email, unique: true, where: "deleted_at IS NULL"
```

Default error: `"has already been taken"`

## validates_associated

```ruby
class Library < ApplicationRecord
  has_many :books
  validates_associated :books  # calls valid? on each associated book
end
```

**Rules:**
- Only use on the parent side, never both sides (infinite loop)
- Only works with ActiveRecord objects
- Errors stay on the child objects, they don't bubble up
- Consider if you actually need this — `autosave: true` on the association already validates before saving

Default error: `"is invalid"`

## validates_each

Block-based validation for quick custom checks without a full method:

```ruby
validates_each :name, :surname do |record, attr, value|
  record.errors.add(attr, "must start with uppercase") if /\A[[:lower:]]/.match?(value)
end
```

## validates_with

```ruby
# Simple:
validates_with AddressValidator

# With options:
validates_with AddressValidator, fields: [:street, :city, :zip]

# Multiple validators:
validates_with FirstValidator, SecondValidator

# Conditional:
validates_with ShippingValidator, if: :requires_shipping?
```

**Important:** The validator instance is shared across all validations (initialized once per app lifecycle). Don't use instance variables for per-validation state.

---

## Normalizations Deep Dive

Rails 7.1+ `normalizes` declaration. Runs before validation AND on attribute assignment.

### Basic patterns

```ruby
class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :phone, with: ->(phone) { phone.gsub(/[^\d+]/, "") }  # keep digits and +
  normalizes :name, with: ->(name) { name.squish }                  # collapse all whitespace
  normalizes :website, with: ->(url) { url.strip.downcase.delete_suffix("/") }
end
```

### When normalizations run

```ruby
user = User.new
user.email = "  FOO@BAR.COM  "
user.email  # => "foo@bar.com"  — normalized on assignment

User.find_by(email: "  FOO@BAR.COM  ")
# SQL: SELECT * FROM users WHERE email = 'foo@bar.com'
# Normalization applied to the query value too!

User.where(email: "  FOO@BAR.COM  ").first
# Also normalized in where clauses
```

### Handling nil

By default, normalization lambdas receive `nil` when the attribute is nil. Handle it:

```ruby
# Option 1: Guard in lambda
normalizes :email, with: ->(email) { email&.strip&.downcase }

# Option 2: apply_to_nil: false (skip normalization for nil entirely)
normalizes :nickname, with: ->(n) { n.strip }, apply_to_nil: false
```

### Normalization + uniqueness interaction

```ruby
class User < ApplicationRecord
  normalizes :email, with: ->(e) { e.strip.downcase }
  validates :email, uniqueness: true
end

# Now "FOO@BAR.COM" and "foo@bar.com" are the same — no duplicates from case.
# The uniqueness query also normalizes, so the SELECT matches correctly.
```

Without normalization, you'd need `uniqueness: { case_sensitive: false }` which generates a slower `LOWER()` query.
