---
name: active-record-validations
description: Expert guidance for Active Record validations in Rails 8.1. Use when adding validations, writing "validates", "validate", working with "errors", "valid?", "invalid?", building custom validators, handling uniqueness, presence, format validation, numericality, conditional validations, strict validations, or normalizations. Covers model-layer data integrity, DB constraint pairing, error handling, and common pitfalls.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails *), Bash(bundle exec *)
---

# Active Record Validations Expert

Write correct, layered validations for Rails 8.1 applications. Pair every model validation with appropriate database constraints. Never rely on model validations alone for data integrity.

## Philosophy

1. **Validations are UX, constraints are safety** — Model validations produce friendly error messages. DB constraints prevent corrupt data. You need both.
2. **Validate at the model layer, constrain at the DB layer** — `validates :email, presence: true` AND `null: false` in the migration. Always.
3. **Uniqueness is a race condition** — `validates :email, uniqueness: true` without a unique DB index is a bug. Full stop.
4. **Normalize before you validate** — Use `normalizes` (Rails 7.1+) to strip/downcase BEFORE validation runs. Don't validate messy input.
5. **Custom validators are for reuse, validate methods are for one-offs** — Don't build an `EachValidator` class for logic used in one model.

## Critical Rules — Read These First

### Pair validations with DB constraints

```ruby
# Model
class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
end

# Migration — without this, anything that bypasses Active Record (bulk imports, raw SQL, other apps) can insert invalid data
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false  # backs presence
      t.timestamps
    end
    add_index :users, :email, unique: true  # backs uniqueness
  end
end
```

**Pairing cheat sheet:**

| Validation | DB Constraint |
|---|---|
| `presence: true` | `null: false` |
| `uniqueness: true` | `add_index unique: true` |
| `uniqueness: { scope: :tenant_id }` | `add_index [:tenant_id, :email], unique: true` |
| `numericality: { greater_than: 0 }` | `CHECK` constraint (optional but ideal) |
| `inclusion: { in: %w[a b c] }` | `CHECK` constraint or enum type |
| `length: { maximum: 255 }` | `limit: 255` on column |

### Uniqueness validation alone is a race condition

```ruby
# Two concurrent requests can both pass validation and insert duplicates:
validates :slug, uniqueness: true
# Without: add_index :posts, :slug, unique: true

# Handle the DB constraint error in your controller:
def create
  @user = User.new(user_params)
  @user.save!
rescue ActiveRecord::RecordNotUnique
  @user.errors.add(:email, :taken)
  render :new, status: :unprocessable_entity
end
```

### Normalize before validating

```ruby
class User < ApplicationRecord
  # Rails 7.1+ normalizations — runs before validation
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :name, with: ->(name) { name.strip }

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
end
```

Without normalization, `" Alice@Example.COM "` fails uniqueness checks against `"alice@example.com"` — or worse, creates a duplicate.

### Boolean presence is special

```ruby
# WRONG — false.blank? is true, so this rejects false!
validates :active, presence: true

# RIGHT — validates the value is actually true or false
validates :active, inclusion: { in: [true, false] }

# Also acceptable
validates :active, exclusion: { in: [nil] }
```

## Instructions

### Step 1: Choose the Right Validation

Before writing a validation, ask: "Where does this rule belong?"

| Rule Type | Where | Example |
|---|---|---|
| Data exists | Model + DB `null: false` | `validates :name, presence: true` |
| Data is unique | Model + DB unique index | `validates :email, uniqueness: true` |
| Data format | Model only (DB can't regex efficiently) | `validates :email, format: { with: /.../ }` |
| Business logic | Model `validate` method | `validate :end_after_start` |
| Referential integrity | DB foreign key | `add_foreign_key` in migration |
| Cross-record consistency | DB constraint or service object | CHECK constraint or transaction |

### Step 2: Use Built-in Validators Correctly

#### presence

```ruby
validates :title, presence: true
# Checks: !value.blank? (rejects nil, "", "   ")
# Pair with: null: false in migration
```

For associations, validate the association, not the foreign key:

```ruby
# WRONG — only checks the integer column isn't nil
validates :author_id, presence: true

# RIGHT — also verifies the Author record exists
belongs_to :author  # Rails 5+ validates presence by default
```

`belongs_to` validates presence by default since Rails 5. To make it optional: `belongs_to :author, optional: true`.

#### uniqueness

```ruby
validates :email, uniqueness: true
validates :name, uniqueness: { scope: :account_id }  # unique per account
validates :slug, uniqueness: { case_sensitive: false }
validates :email, uniqueness: { conditions: -> { where(deleted_at: nil) } }
```

**Always add the matching unique index in a migration.**

#### format

```ruby
# Use \A and \z for string boundaries, not ^ and $
validates :username, format: { with: /\A[a-z0-9_]+\z/ }

# ^ and $ match LINE boundaries in Ruby, not string boundaries.
# "valid\nevil" passes /^[a-z]+$/ — this is a security hole that enables injection attacks.
```

#### numericality

```ruby
validates :price, numericality: { greater_than: 0 }
validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
validates :discount, numericality: { in: 0..100 }
```

**Gotcha:** `numericality` rejects `nil` by default. If the field is optional, add `allow_nil: true`.

**Gotcha:** Float precision — `numericality` converts to `Float` then `BigDecimal`. For money, use `decimal` columns with explicit precision/scale and validate as integer cents, or use a money gem.

#### length

```ruby
validates :name, length: { minimum: 2, maximum: 100 }
validates :bio, length: { maximum: 500 }
validates :pin, length: { is: 4 }
validates :password, length: { in: 8..128 }
```

#### inclusion / exclusion

```ruby
validates :role, inclusion: { in: %w[admin editor viewer] }
validates :subdomain, exclusion: { in: %w[www admin api] }

# Dynamic:
validates :size, inclusion: { in: ->(record) { record.available_sizes } }
```

#### comparison

```ruby
validates :end_date, comparison: { greater_than: :start_date }
validates :retry_count, comparison: { less_than_or_equal_to: 10 }
```

#### confirmation

```ruby
validates :email, confirmation: true
validates :email_confirmation, presence: true  # confirmation field itself must be present

# Only validate confirmation when email changes:
validates :email, confirmation: true
validates :email_confirmation, presence: true, if: :email_changed?
```

#### acceptance

```ruby
validates :terms, acceptance: true  # virtual attribute, no DB column needed
validates :eula, acceptance: { accept: ["TRUE", "accepted"] }
```

#### absence

```ruby
validates :supplementary_address, absence: true, unless: :has_primary_address?
```

#### validates_associated

```ruby
has_many :line_items
validates_associated :line_items  # calls valid? on each line_item

# Don't put validates_associated on BOTH sides of an association — it creates
# an infinite loop (parent validates child, child validates parent, etc.).
# Parent validates children; children rely on belongs_to for the reverse.
```

### Step 3: Conditional Validations

Use `:if` / `:unless` to scope when validations run.

```ruby
# Symbol — cleanest for named methods
validates :card_number, presence: true, if: :paid_with_card?

# Lambda — fine for one-liners
validates :company_name, presence: true, if: -> { account_type == "business" }

# Group related conditionals with with_options
with_options if: :is_admin? do
  validates :password, length: { minimum: 10 }
  validates :email, presence: true
end

# Combine conditions (ALL :if must be true, NO :unless can be true)
validates :parking_spot, presence: true,
  if: [:has_car?, :works_onsite?],
  unless: -> { remote_employee? }
```

**Prefer named methods over complex lambdas** — a method name communicates intent (`paid_with_card?`) better than inline logic, and it's easier to test independently.

#### on: context

```ruby
validates :email, uniqueness: true, on: :create  # skip on update
validates :age, numericality: true, on: :update

# Custom contexts for multi-step forms:
validates :address, presence: true, on: :checkout
# Trigger: user.valid?(:checkout) or user.save(context: :checkout)
```

### Step 4: Custom Validations

#### validate method (one-off, single model)

```ruby
class Event < ApplicationRecord
  validate :end_after_start
  validate :not_in_past, on: :create

  private

  def end_after_start
    return if end_date.blank? || start_date.blank?
    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def not_in_past
    return if start_date.blank?
    if start_date < Date.current
      errors.add(:start_date, "can't be in the past")
    end
  end
end
```

**Guard against nil** with `return if field.blank?` — custom validations receive nil when the field is empty, which causes NoMethodError. Let `presence` handle the "is it present?" check separately.

#### EachValidator (reusable across models)

```ruby
# app/validators/email_validator.rb
class EmailValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless URI::MailTo::EMAIL_REGEXP.match?(value)
      record.errors.add(attribute, options[:message] || "is not a valid email")
    end
  end
end

# Usage — name becomes the validation key (email:)
class User < ApplicationRecord
  validates :email, email: true
  validates :backup_email, email: true, allow_blank: true
end
```

**Naming convention:** `XxxValidator` → `validates :attr, xxx: true`. The class name minus `Validator`, lowercased/underscored.

#### Validator class (validates_with, complex cross-field)

```ruby
# app/validators/address_validator.rb
class AddressValidator < ActiveModel::Validator
  def validate(record)
    %i[street city zip].each do |field|
      if record.send(field).blank?
        record.errors.add(field, "is required for a complete address")
      end
    end
  end
end

class Order < ApplicationRecord
  validates_with AddressValidator, if: :shipping_required?
end
```

**Note:** `validates_with` validators are initialized once for the app lifecycle. Storing instance state causes data to leak between validations of different records.

### Step 5: Error Handling

#### Reading errors

```ruby
record.valid?                          # triggers validations, returns bool
record.errors.full_messages            # ["Name can't be blank", ...]
record.errors[:name]                   # ["can't be blank", "is too short..."]
record.errors.where(:name, :too_short) # [ActiveModel::Error objects]
record.errors.added?(:name, :blank)    # true/false — check specific error type
record.errors.of_kind?(:name, :blank)  # same as added? but doesn't check options
```

#### Adding errors manually

```ruby
errors.add(:email, :invalid)                            # uses i18n default
errors.add(:email, :taken, value: email)                # interpolates %{value}
errors.add(:base, "Something is wrong with this record") # record-level error
```

#### Custom error types for programmatic handling

```ruby
errors.add(:discount, :exceeds_maximum, count: 50)
# In en.yml:
# activerecord.errors.models.order.attributes.discount.exceeds_maximum: "cannot exceed %{count}%"
```

#### Displaying in views

```erb
<% if @record.errors.any? %>
  <div id="error_explanation">
    <h2><%= pluralize(@record.errors.count, "error") %> prohibited saving:</h2>
    <ul>
      <% @record.errors.each do |error| %>
        <li><%= error.full_message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### Step 6: Strict Validations

Use for programmer errors, not user input errors.

```ruby
validates :token, presence: { strict: true }
# Raises ActiveModel::StrictValidationFailed instead of adding to errors

validates :token, presence: { strict: TokenMissingError }
# Raises your custom exception
```

**Use strict validations for:** internal invariants, system-generated fields, things that should never fail if code is correct. **Don't use for:** user-facing form fields.

### Step 7: Normalizations (Rails 7.1+)

```ruby
class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :phone, with: ->(phone) { phone.gsub(/\D/, "") }
  normalizes :name, with: ->(name) { name.squish }  # collapse whitespace

  # apply: false — skip normalization on nil (default normalizes nil too)
  normalizes :nickname, with: ->(n) { n.strip }, apply_to_nil: false
end

# Normalizations run:
# - On assignment: user.email = " FOO@BAR.COM " → "foo@bar.com"
# - Before validation
# - On finder methods: User.find_by(email: " FOO@BAR.COM ") normalizes the query value
```

**Normalize before you validate.** Without this, `" Alice@Example.COM "` and `"alice@example.com"` are treated as different values — leading to duplicates, failed lookups, and confusing error messages.

## Methods That Skip Validations

These methods write to DB without running validations. Know them:

`update_all`, `update_column`, `update_columns`, `insert`, `insert!`, `insert_all`, `insert_all!`, `upsert`, `upsert_all`, `touch`, `touch_all`, `toggle!`, `increment!`, `decrement!`, `update_attribute`, `save(validate: false)`

**If you use these, your DB constraints are your only safety net.** This is why DB constraints matter.

## Common Mistakes Agents Make

1. **Adding `validates :foo, presence: true` without `null: false` in migration** — Data will be inconsistent if anything bypasses Active Record.

2. **Using `validates :email, uniqueness: true` without a unique index** — Race condition. Two concurrent requests can both pass validation and insert duplicates.

3. **Validating boolean presence** — `validates :active, presence: true` rejects `false`. Use `inclusion: { in: [true, false] }`.

4. **Using `^` and `$` in format regexes** — Use `\A` and `\z`. Line anchors allow injection via newlines.

5. **Not guarding nil in custom validate methods** — If `presence` is optional, your custom method gets `nil` and raises `NoMethodError`.

6. **Putting validates_associated on both sides** — Infinite loop. Only parent validates children.

7. **Forgetting that numericality rejects nil** — Add `allow_nil: true` if the field is optional.

8. **Not normalizing before uniqueness checks** — `"foo@bar.com"` and `"Foo@Bar.com"` are different without normalization/`case_sensitive: false`.

9. **Validating foreign key column instead of association** — `validates :author_id, presence: true` doesn't verify the author exists. `belongs_to :author` does.

10. **Writing EachValidator for single-model logic** — Overkill. Use a `validate` method unless you need it in 2+ models.

## Quick Reference

### Validation triggers (run validations)

`create`, `create!`, `save`, `save!`, `update`, `update!`, `valid?`, `invalid?`

### Options available on all validators

| Option | Purpose |
|---|---|
| `:message` | Custom error message (String or Proc) |
| `:on` | Context — `:create`, `:update`, or custom symbol |
| `:if` / `:unless` | Conditional — symbol, proc, or array |
| `:allow_nil` | Skip if value is `nil` |
| `:allow_blank` | Skip if value is `blank?` |
| `:strict` | Raise exception instead of adding error |

### Message interpolation

```ruby
validates :name, length: { minimum: 3, message: "must be at least %{count} characters" }
# Available: %{value}, %{attribute}, %{model}, %{count}

validates :email, uniqueness: {
  message: ->(object, data) { "#{data[:value]} is already taken" }
}
```

See the `references/` directory for complete examples and edge cases:
- `references/built-in-validators.md` — All built-in validators with options, edge cases, and normalizations
- `references/custom-validators.md` — EachValidator, Validator classes, PORO validators
- `references/errors-api.md` — Errors API (reading, adding, filtering) and I18n configuration
- `references/conditional-validations.md` — if/unless, with_options, :on context, multi-step forms
- `references/db-constraints.md` — DB constraint pairing, uniqueness race conditions, numericality edge cases
- `references/testing.md` — Testing patterns, performance considerations, miscellaneous recipes
