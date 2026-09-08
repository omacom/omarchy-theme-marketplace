# Active Record Callbacks — Reference

Detailed patterns, examples, edge cases, and the complete API reference for Active Record callbacks in Rails 8.1.

## Table of Contents
- [Complete Lifecycle Order](#complete-lifecycle-order)
- [Methods That Trigger Callbacks](#methods-that-trigger-callbacks)
- [Registration Patterns](#registration-patterns)
- [Conditional Callbacks](#conditional-callbacks)
- [Transaction Callbacks In Depth](#transaction-callbacks-in-depth)
- [Halting the Callback Chain](#halting-the-callback-chain)
- [Association Callbacks](#association-callbacks)
- [Cascading Callbacks via `dependent:`](#cascading-callbacks-via-dependent)
- [Suppressing Callbacks](#suppressing-callbacks)
- [Dirty Tracking in Callbacks](#dirty-tracking-in-callbacks)
- [Common Patterns](#common-patterns)
- [Testing Callbacks](#testing-callbacks)
- [Debugging Callbacks](#debugging-callbacks)
- [Decision Framework](#decision-framework)

## Complete Lifecycle Order

### Creating (`User.create` / `User.new` + `save`)

```
1.  before_validation
2.  after_validation
3.  before_save
4.  around_save ↓
5.    before_create
6.    around_create ↓
7.      [SQL INSERT]
8.    around_create ↑ (after yield)
9.    after_create
10. around_save ↑ (after yield)
11. after_save
12. after_commit (on success) / after_rollback (on failure)
```

### Updating (`user.update` / `user.save` on existing)

```
1.  before_validation
2.  after_validation
3.  before_save
4.  around_save ↓
5.    before_update
6.    around_update ↓
7.      [SQL UPDATE]
8.    around_update ↑ (after yield)
9.    after_update
10. around_save ↑ (after yield)
11. after_save
12. after_commit (on success) / after_rollback (on failure)
```

### Destroying (`user.destroy`)

```
1.  before_destroy
2.  around_destroy ↓
3.    [SQL DELETE]
4.  around_destroy ↑ (after yield)
5.  after_destroy
6.  after_commit (on success) / after_rollback (on failure)
```

### Special Callbacks

| Callback | Triggered By | Notes |
|----------|-------------|-------|
| `after_initialize` | `new`, `find`, `find_by`, etc. | Every instantiation. No `before_` counterpart. |
| `after_find` | `find`, `first`, `last`, `all`, etc. | Only DB loads, not `new`. Fires before `after_initialize`. |
| `after_touch` | `touch`, `belongs_to touch: true` | Cascades via associations. |

## Methods That Trigger Callbacks

### These DO trigger callbacks:
- `create` / `create!`
- `save` / `save!`
- `save(validate: false)` / `save!(validate: false)` — skips validation callbacks but runs save/create/update callbacks
- `update` / `update!`
- `update_attribute` / `update_attribute!` — skips validation but runs save callbacks
- `destroy` / `destroy!`
- `destroy_all` / `destroy_by`
- `toggle!`
- `touch`
- `valid?` / `validate` — triggers validation callbacks only

### These SKIP callbacks:
- `update_column(attr, value)` — single attribute, no callbacks, no validations, no `updated_at`
- `update_columns(attrs)` — multiple attributes, same skips
- `update_all` — bulk update via SQL
- `delete` — single record, no callbacks (vs `destroy`)
- `delete_all` / `delete_by` — bulk delete, no callbacks
- `insert` / `insert!` / `insert_all` / `insert_all!` — bulk insert
- `upsert` / `upsert_all` — insert or update
- `increment!` / `decrement!` — counter changes
- `increment_counter` / `decrement_counter` — class-level counters
- `touch_all` — bulk touch
- `update_counters` — counter cache updates

## Registration Patterns

### Method Reference (Preferred)

```ruby
class User < ApplicationRecord
  before_validation :normalize_email
  before_create :set_defaults
  after_commit :enqueue_welcome_email, on: :create

  private

  def normalize_email
    self.email = email&.strip&.downcase
  end

  def set_defaults
    self.role ||= "member"
    self.locale ||= "en"
  end

  def enqueue_welcome_email
    WelcomeEmailJob.perform_later(id)
  end
end
```

### Block (One-Liners Only)

```ruby
class User < ApplicationRecord
  before_save { self.email = email&.downcase }
  after_initialize { self.role ||= "member" }
end
```

### Callback Object (Cross-Model Reuse)

**Class method style (no instantiation needed):**

```ruby
class StripWhitespace
  SKIP_COLUMNS = %w[id created_at updated_at].freeze

  def self.before_save(record)
    record.attributes.each do |key, value|
      next if SKIP_COLUMNS.include?(key)
      record[key] = value.strip if value.is_a?(String)
    end
  end
end

class User < ApplicationRecord
  before_save StripWhitespace
end

class Post < ApplicationRecord
  before_save StripWhitespace
end
```

**Instance method style (when callback needs state):**

```ruby
class EncryptField
  def initialize(field)
    @field = field
  end

  def before_save(record)
    if record.send("#{@field}_changed?")
      record.send("#{@field}=", encrypt(record.send(@field)))
    end
  end

  private

  def encrypt(value)
    # encryption logic
  end
end

class User < ApplicationRecord
  before_save EncryptField.new(:ssn)
end
```

### Scoping to Lifecycle Events with `:on`

```ruby
class User < ApplicationRecord
  before_validation :set_defaults, on: :create
  after_validation :geocode_address, on: [:create, :update]
end
```

## Conditional Callbacks

### `:if` with Symbol

```ruby
class Order < ApplicationRecord
  before_save :normalize_card_number, if: :paid_with_card?

  private

  def paid_with_card?
    payment_method == "card"
  end

  def normalize_card_number
    self.card_number = card_number.gsub(/\s/, "")
  end
end
```

### `:if` with Proc

```ruby
class Order < ApplicationRecord
  before_save :normalize_card_number, if: -> { paid_with_card? }
  # Or with explicit parameter:
  before_save :normalize_card_number, if: ->(order) { order.paid_with_card? }
end
```

### Multiple Conditions (Array)

All conditions must be truthy for callback to fire:

```ruby
class Comment < ApplicationRecord
  before_save :filter_content,
    if: [:subject_to_parental_control?, :untrusted_author?]
end
```

### Combined `:if` and `:unless`

Callback fires when ALL `:if` conditions are true AND ALL `:unless` conditions are false:

```ruby
class Comment < ApplicationRecord
  before_save :filter_content,
    if: -> { forum.parental_control? },
    unless: -> { author.trusted? }
end
```

## Transaction Callbacks In Depth

### `after_save` vs `after_commit` — The Critical Difference

```ruby
class User < ApplicationRecord
  # ❌ DANGEROUS: Email sent, then transaction rolls back → user never created but got email
  after_save :send_welcome_email

  # ✅ SAFE: Email only sent after transaction commits
  after_commit :send_welcome_email, on: :create
end
```

**Real-world scenario:**

```ruby
User.transaction do
  user = User.create!(email: "test@example.com")  # after_save fires HERE
  account = Account.create!(user: user)            # This might raise!
end
# If Account.create! raises → transaction rolls back
# But after_save already ran → email sent for non-existent user
# after_commit would NOT have fired → safe
```

### Convenience Aliases

```ruby
class User < ApplicationRecord
  after_create_commit :send_welcome       # Only on create
  after_update_commit :sync_changes       # Only on update
  after_destroy_commit :cleanup_files     # Only on destroy
  after_save_commit :broadcast_changes    # Create OR update
end
```

### ⚠️ Gotcha: Duplicate Method Names

```ruby
# BUG — they alias to after_commit internally, second overwrites first
after_create_commit :notify
after_update_commit :notify  # Only THIS one works

# FIX — use after_save_commit if both need the same method
after_save_commit :notify

# FIX — or use separate methods
after_create_commit :notify_creation
after_update_commit :notify_update
```

### `after_commit` Fires Once Per Record Per Transaction

```ruby
class User < ApplicationRecord
  after_update_commit :log_update

  private

  def log_update
    Rails.logger.info("User #{id} updated")
  end
end

User.transaction do
  user.update!(name: "First")
  user.update!(name: "Second")
end
# log_update fires ONCE, not twice
# The record's state reflects the FINAL update
```

### `after_commit` Only Fires on First Loaded Object

```ruby
User.transaction do
  user1 = User.find(1)
  user2 = User.find(1)  # Same DB record, different Ruby object
  user1.update!(name: "Changed")
end
# after_commit fires on user1 only, NOT user2
```

### Per-Transaction Callbacks

Register callbacks on the transaction itself (not the model):

```ruby
Article.transaction do |transaction|
  article.update!(published: true)

  transaction.after_commit do
    PublishNotificationMailer.with(article: article).deliver_later
  end
end
```

### `ActiveRecord.after_all_transactions_commit`

Fires after the **outermost** transaction commits. Useful in nested transactions:

```ruby
def publish_article(article)
  Article.transaction do
    Post.transaction do
      ActiveRecord.after_all_transactions_commit do
        PublishNotificationMailer.with(article: article).deliver_later
      end
    end
  end
end
```

If called outside a transaction, the block executes immediately.

### Transaction Callback Ordering

Rails 7.1+ runs transaction callbacks **in definition order** (top to bottom):

```ruby
class User < ActiveRecord::Base
  after_commit { Rails.logger.info("first") }   # Runs first
  after_commit { Rails.logger.info("second") }  # Runs second
end
```

Prior Rails versions ran them in reverse. To restore old behavior:

```ruby
config.active_record.run_after_transaction_callbacks_in_order_defined = false
```

### Exception Handling in `after_commit`

If one `after_commit` raises, remaining `after_commit` callbacks are **skipped**:

```ruby
class User < ActiveRecord::Base
  after_commit { raise "boom" }
  after_commit { Rails.logger.info("this never runs") }
end
```

Rescue within the callback to prevent this:

```ruby
after_commit :safe_sync

def safe_sync
  ExternalService.sync(self)
rescue => e
  Rails.logger.error("Sync failed: #{e.message}")
  Sentry.capture_exception(e)
end
```

## Halting the Callback Chain

### `throw :abort`

```ruby
class Account < ApplicationRecord
  before_destroy :ensure_deletable

  private

  def ensure_deletable
    if subscriptions.active.any?
      errors.add(:base, "Cannot delete with active subscriptions")
      throw :abort
    end
  end
end

account.destroy   # => false (check account.errors for reason)
account.destroy!  # => raises ActiveRecord::RecordNotDestroyed
```

### Raising Exceptions

```ruby
class Product < ApplicationRecord
  before_validation do
    raise ArgumentError, "Price can't be negative" if total_price&.negative?
  end
end

Product.create(total_price: -1)  # Raises ArgumentError (unrescued!)
```

**Prefer `throw :abort`** — it's the Rails convention and doesn't break callers expecting `save` to return a boolean.

### Exceptions: `ActiveRecord::Rollback`

The only exception that triggers rollback WITHOUT re-raising:

```ruby
class User < ApplicationRecord
  after_save do
    raise ActiveRecord::Rollback if some_condition?
    # Transaction rolls back, but NO exception propagates
    # save returns false
  end
end
```

## Association Callbacks

Different from model callbacks — these fire when objects are added/removed from a collection:

```ruby
class Author < ApplicationRecord
  has_many :books,
    before_add: :check_book_limit,
    after_add: :update_book_count,
    before_remove: :verify_can_remove,
    after_remove: :update_book_count

  private

  def check_book_limit(book)
    if books.count >= 10
      errors.add(:base, "Maximum 10 books per author")
      throw :abort
    end
  end

  def update_book_count(_book)
    update_column(:books_count, books.count)
  end

  def verify_can_remove(book)
    throw :abort if book.published?
  end
end
```

**Important:** These only fire through the association:

```ruby
author.books << book        # ✅ Triggers before_add
author.books = [book]       # ✅ Triggers before_add
book.update(author_id: 1)   # ❌ Does NOT trigger before_add
```

Multiple callbacks as array:

```ruby
has_many :books, before_add: [:check_limit, :validate_genre]
```

## Cascading Callbacks via `dependent:`

```ruby
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
end

class Post < ApplicationRecord
  after_destroy :log_deletion

  def log_deletion
    Rails.logger.info("Post #{id} destroyed")
  end
end

user.destroy
# Each post's after_destroy fires individually
# "Post 1 destroyed", "Post 2 destroyed", etc.
```

### `before_destroy` + `dependent: :destroy` Order

```ruby
# ❌ WRONG — dependent: :destroy runs first, then before_destroy
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  before_destroy :check_can_delete  # Posts already deleted!
end

# ✅ FIX 1 — prepend: true
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  before_destroy :check_can_delete, prepend: true
end

# ✅ FIX 2 — declare callback before association
class User < ApplicationRecord
  before_destroy :check_can_delete
  has_many :posts, dependent: :destroy
end
```

## Suppressing Callbacks

### `ActiveRecord::Suppressor`

Prevents saves of a specific model within a block:

```ruby
class User < ApplicationRecord
  after_create :create_notification

  def create_notification
    Notification.create!(user: self, event: "signup")
  end
end

# In tests or data migrations:
Notification.suppress do
  User.create!(name: "Test")  # Notification.create! is silently skipped
end
```

### Skipping via SQL Methods

For when you need to bypass all callbacks:

```ruby
# Update without callbacks
user.update_columns(login_count: user.login_count + 1)

# Bulk update without callbacks
User.where(active: false).update_all(archived: true)

# Delete without callbacks
user.delete  # vs user.destroy which fires callbacks

# Insert without callbacks
User.insert_all([{ name: "A" }, { name: "B" }])
```

## Dirty Tracking in Callbacks

### In `before_*` Callbacks (Changes Pending)

```ruby
class User < ApplicationRecord
  before_save :track_changes

  private

  def track_changes
    if email_changed?
      # email_was → old value
      # email → new value (not yet saved)
      # email_change → [old, new]
      Rails.logger.info("Email changing from #{email_was} to #{email}")
    end

    if will_save_change_to_email?
      # Preferred Rails 5.1+ API
      Rails.logger.info("Email will change")
    end
  end
end
```

### In `after_*` Callbacks (Changes Applied)

```ruby
class User < ApplicationRecord
  after_save :track_saved_changes

  private

  def track_saved_changes
    if saved_change_to_email?
      old_email, new_email = saved_change_to_email
      Rails.logger.info("Email changed from #{old_email} to #{new_email}")
    end

    # All changes that were just saved
    saved_changes.each do |attr, (old_val, new_val)|
      Rails.logger.info("#{attr}: #{old_val} → #{new_val}")
    end
  end
end
```

### Summary of Dirty Methods

| Method | Use In | Returns |
|--------|--------|---------|
| `attribute_changed?` | `before_*` | Boolean |
| `attribute_was` | `before_*` | Old value |
| `attribute_change` | `before_*` | `[old, new]` |
| `will_save_change_to_attribute?` | `before_*` | Boolean (preferred) |
| `attribute_change_to_be_saved` | `before_*` | `[old, new]` (preferred) |
| `saved_change_to_attribute?` | `after_*` | Boolean |
| `saved_change_to_attribute` | `after_*` | `[old, new]` |
| `saved_changes` | `after_*` | Hash of all changes |
| `attribute_before_last_save` | `after_*` | Previous value |

## Common Patterns

### Setting Defaults

```ruby
class User < ApplicationRecord
  before_validation :set_defaults, on: :create

  private

  def set_defaults
    self.role ||= "member"
    self.timezone ||= "UTC"
    self.locale ||= I18n.default_locale
  end
end
```

### Generating Tokens

```ruby
class ApiKey < ApplicationRecord
  before_create :generate_token

  private

  def generate_token
    loop do
      self.token = SecureRandom.hex(32)
      break unless self.class.exists?(token: token)
    end
  end
end
```

### Slug Generation

```ruby
class Post < ApplicationRecord
  before_validation :generate_slug, on: :create

  private

  def generate_slug
    self.slug = title&.parameterize
  end
end
```

### Normalizing Data

```ruby
class Contact < ApplicationRecord
  before_save :normalize_phone
  before_save :normalize_email

  private

  def normalize_phone
    self.phone = phone&.gsub(/[\s\-\(\)]/, "")
  end

  def normalize_email
    self.email = email&.strip&.downcase
  end
end
```

### Safe External Calls via `after_commit`

```ruby
class Order < ApplicationRecord
  after_create_commit :sync_to_fulfillment

  private

  def sync_to_fulfillment
    FulfillmentSyncJob.perform_later(id)
  rescue => e
    Rails.logger.error("Failed to enqueue fulfillment sync: #{e.message}")
  end
end
```

### Preventing Deletion

```ruby
class Organization < ApplicationRecord
  before_destroy :ensure_no_members, prepend: true

  private

  def ensure_no_members
    if users.any?
      errors.add(:base, "Cannot delete organization with members")
      throw :abort
    end
  end
end
```

### Cache Invalidation

```ruby
class Product < ApplicationRecord
  after_commit :invalidate_cache

  private

  def invalidate_cache
    Rails.cache.delete("product/#{id}")
    Rails.cache.delete("products/catalog")
  end
end
```

## Testing Callbacks

### Test the Behavior, Not the Callback

```ruby
# ❌ Testing that a callback exists (implementation detail)
test "has before_save callback" do
  assert User._save_callbacks.any? { |c| c.filter == :normalize_email }
end

# ✅ Testing the behavior (what matters)
test "normalizes email on save" do
  user = users(:active_user)
  user.email = "  JOHN@Example.COM  "
  user.save!
  assert_equal "john@example.com", user.email
end
```

### Testing Halting

```ruby
test "cannot destroy account with active subscriptions" do
  account = accounts(:with_subscription)
  refute account.destroy
  assert_includes account.errors[:base], "Cannot delete with active subscriptions"
  assert Account.exists?(account.id)
end
```

### Testing `after_commit` with Transactions

```ruby
test "enqueues welcome email after creation" do
  assert_enqueued_with(job: WelcomeEmailJob) do
    User.create!(name: "Test", email: "test@example.com")
  end
end
```

### Skipping Callbacks in Tests

When callbacks interfere with test setup:

```ruby
# Option 1: Use methods that skip callbacks
user.update_columns(email: "test@example.com")

# Option 2: Suppress specific models
Notification.suppress do
  User.create!(name: "Test")
end
```

## Debugging Callbacks

### List All Callbacks on a Model

```ruby
# In rails console
User._save_callbacks.map { |c| [c.kind, c.filter] }
# => [[:before, :normalize_email], [:after, :update_cache]]

User._create_callbacks.map { |c| [c.kind, c.filter] }
User._update_callbacks.map { |c| [c.kind, c.filter] }
User._destroy_callbacks.map { |c| [c.kind, c.filter] }
User._validation_callbacks.map { |c| [c.kind, c.filter] }
User._commit_callbacks.map { |c| [c.kind, c.filter] }
```

### Tracing Callback Execution

```ruby
# Temporary debugging — add to model
around_save :debug_callbacks

def debug_callbacks
  Rails.logger.info("=== BEFORE SAVE === #{changes.inspect}")
  yield
  Rails.logger.info("=== AFTER SAVE === #{saved_changes.inspect}")
end
```

## Decision Framework

```
Is this logic model-intrinsic?
├── YES: Does it need data from outside the model?
│   ├── YES → Service object (not a callback)
│   └── NO: Is it simple data transformation?
│       ├── YES → before_save / before_validation callback ✅
│       └── NO: Does it talk to external systems?
│           ├── YES → after_commit + background job ✅
│           └── NO → Evaluate case-by-case
└── NO → Service object (not a callback)
```
