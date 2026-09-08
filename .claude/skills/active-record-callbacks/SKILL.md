---
name: active-record-callbacks
description: Expert guidance for Active Record callbacks — lifecycle hooks, ordering, conditional execution, transaction callbacks, and halting. VERY opinionated about when NOT to use callbacks. Use when working with callbacks, before_save, after_create, after_commit, lifecycle hooks, before_validation, around_save, after_update, before_destroy, or when deciding whether logic belongs in a callback vs a service object.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails *), Bash(bundle exec rails *)
---

# Active Record Callbacks

Hook into the lifecycle of Active Record objects — but only when it's the right tool.

## When To Use This Skill

- Adding or modifying model callbacks (before_save, after_create, after_commit, etc.)
- Deciding whether logic belongs in a callback vs a service object
- Debugging unexpected callback behavior or ordering issues
- Implementing transaction-safe side effects (after_commit patterns)
- Halting the callback chain or suppressing callbacks

## The Golden Rule

**Callbacks are for model-intrinsic concerns ONLY.** If the logic wouldn't make sense as a column default or database constraint, it probably doesn't belong in a callback.

### ✅ USE Callbacks For

- **Setting defaults** — `before_validation :set_default_role`
- **Normalizing data** — `before_save :strip_whitespace`, `before_save :downcase_email`
- **Deriving values** — `before_save :calculate_total_from_line_items`
- **Generating tokens/slugs** — `before_create :generate_uuid`
- **Maintaining counter caches** — when Rails built-in isn't enough
- **Touching timestamps** — simple `updated_at` propagation
- **Cleaning up owned resources** — `after_destroy_commit :delete_file_from_storage`

### ❌ DO NOT USE Callbacks For

- **Sending emails** → Service object or `after_commit` + job at minimum
- **Calling external APIs** → Service object
- **Creating other records** → Service object
- **Complex business logic** → Service object
- **Anything conditional on context** → Service object (callbacks don't know WHY save was called)
- **Enqueuing jobs** → Use `after_commit`, never `after_save` (data may not be committed yet)
- **Authorization checks** → Controller/policy layer
- **Logging business events** → Service object or `after_commit`

### Why This Matters

Callbacks are the **#1 source of Rails spaghetti.** They:
- Run on EVERY save, even when you don't want them to
- Create invisible coupling (saving User sends an email?!)
- Make debugging nightmarish (callback chains are hard to trace)
- Break in bulk operations (`update_all` skips them entirely)
- Cause test fragility (every test that saves a record triggers the whole chain)

**When in doubt, use a service object.** You can always extract INTO a callback later if it truly is model-intrinsic. Extracting OUT of a callback is much harder.

## Lifecycle Order

### Creating a Record

```
before_validation
after_validation
before_save
around_save
  before_create
  around_create
    [INSERT]
  around_create (after yield)
  after_create
around_save (after yield)
after_save
after_commit / after_rollback
```

### Updating a Record

```
before_validation
after_validation
before_save
around_save
  before_update
  around_update
    [UPDATE]
  around_update (after yield)
  after_update
around_save (after yield)
after_save
after_commit / after_rollback
```

### Destroying a Record

```
before_destroy
around_destroy
  [DELETE]
around_destroy (after yield)
after_destroy
after_commit / after_rollback
```

**Key insight:** `before_save`/`after_save` wrap BOTH create and update. They always run before/after the more specific `before_create`/`after_create` or `before_update`/`after_update`.

## Instructions

### Step 1: Ask "Should This Be a Callback?"

Apply the **intrinsic test**: Would this logic need to run regardless of WHERE or WHY the record is being saved?

- Normalizing an email address? **Yes** — always lowercase it → callback
- Sending a welcome email? **No** — only on signup, not admin edits → service object
- Setting a UUID? **Yes** — always needs one → callback
- Notifying Slack? **No** — depends on context → service object

If the answer involves "only when..." or "except when..." — it's probably NOT a callback. Conditional callbacks (`if:` / `unless:`) are a code smell that the logic doesn't belong here.

### Step 2: Choose the Right Hook

| Need | Hook | Why |
|------|------|-----|
| Set defaults before validation | `before_validation` | Values available for validation |
| Normalize/derive data | `before_save` | Runs on both create and update |
| Set values only on first create | `before_create` | Won't run on updates |
| React after DB write (in transaction) | `after_save` / `after_create` / `after_update` | Data saved but transaction may rollback |
| React after DB commit (safe) | `after_commit` / `after_create_commit` | Transaction committed — safe for jobs, external calls |
| Clean up on delete | `after_destroy_commit` | Record is truly gone |
| Prevent save/destroy | `before_save` / `before_destroy` + `throw :abort` | Halts the chain |

**Critical rule:** If your callback talks to ANYTHING outside the database (APIs, job queues, file systems, mailers), use `after_commit`, not `after_save`. Data inside `after_save` may be rolled back.

### Step 3: Registration

**Prefer private methods with macro-style registration:**

```ruby
class User < ApplicationRecord
  before_validation :normalize_email
  before_create :generate_api_token

  private

  def normalize_email
    self.email = email&.strip&.downcase
  end

  def generate_api_token
    self.api_token = SecureRandom.hex(32)
  end
end
```

**Use blocks only for true one-liners:**

```ruby
class User < ApplicationRecord
  before_save { self.email = email&.downcase }
end
```

**Never use lambda/proc style** — it's harder to read and test:

```ruby
# Don't do this
before_save ->(user) { user.email = user.email&.downcase }
```

### Step 4: Conditional Callbacks (Use Sparingly)

If you need a conditional callback, prefer `:if` / `:unless` with a symbol:

```ruby
class Order < ApplicationRecord
  before_save :normalize_card_number, if: :paid_with_card?
  before_save :apply_discount, unless: :promotional?
end
```

Multiple conditions (all must pass):

```ruby
before_save :archive_data, if: [:completed?, :older_than_90_days?]
```

**Code smell alert:** If you have more than one condition, or complex proc conditions, the logic almost certainly belongs in a service object instead.

### Step 5: Halting the Chain

Use `throw :abort` to prevent the operation:

```ruby
class Account < ApplicationRecord
  before_destroy :ensure_no_active_subscriptions

  private

  def ensure_no_active_subscriptions
    if subscriptions.active.any?
      errors.add(:base, "Cannot delete account with active subscriptions")
      throw :abort
    end
  end
end
```

**Behavior of `throw :abort`:**
- `save` → returns `false`
- `save!` → raises `ActiveRecord::RecordNotSaved`
- `destroy` → returns `false`
- `destroy!` → raises `ActiveRecord::RecordNotDestroyed`

**Never raise exceptions in callbacks** to halt execution. Use `throw :abort`.

### Step 6: Transaction Callbacks (`after_commit`)

**The most important callback distinction in Rails:**

| Hook | When it runs | Transaction state | Safe for external calls? |
|------|-------------|-------------------|-------------------------|
| `after_save` | After INSERT/UPDATE | Still in transaction | ❌ NO — may rollback |
| `after_commit` | After COMMIT | Committed | ✅ YES |
| `after_rollback` | After ROLLBACK | Rolled back | N/A |

**Convenience aliases (prefer these):**

```ruby
class User < ApplicationRecord
  after_create_commit :send_welcome_email_job
  after_update_commit :sync_to_crm_job
  after_destroy_commit :cleanup_storage
  after_save_commit :broadcast_changes  # create OR update
end
```

**Gotcha — `after_create_commit` + `after_update_commit` with same method name:**

```ruby
# BUG: Only after_update_commit will fire — they alias to after_commit internally
after_create_commit :log_change
after_update_commit :log_change  # This overwrites the create one!

# FIX: Use after_save_commit for both
after_save_commit :log_change
```

**Gotcha — `after_commit` runs once per record per transaction:**

```ruby
User.transaction do
  user.update!(name: "First")
  user.update!(name: "Second")
end
# after_commit fires ONCE, not twice
```

### Step 7: Skipping Callbacks

These methods **bypass** callbacks entirely:

- `update_column` / `update_columns` — single record, no callbacks/validations
- `update_all` — bulk update, no callbacks
- `delete` / `delete_all` / `delete_by` — no callbacks (vs `destroy` which fires them)
- `insert` / `insert_all` / `upsert` / `upsert_all` — bulk insert, no callbacks
- `increment!` / `decrement!` — counter updates, no callbacks
- `touch_all` — bulk touch, no callbacks

**Use these intentionally** when you know callbacks aren't needed (e.g., counter updates, bulk data migrations).

### Step 8: `around_*` Callbacks

Wrap the operation with `yield`:

```ruby
class User < ApplicationRecord
  around_save :benchmark_save

  private

  def benchmark_save
    start = Time.current
    yield  # The actual save happens here
    duration = Time.current - start
    Rails.logger.info("User#save took #{duration}s")
  end
end
```

**Avoid `around_*` callbacks unless you genuinely need to wrap the operation** (benchmarking, custom transaction handling). They add complexity and are harder to reason about.

### Step 9: Callback Objects (For Reuse)

Extract into a class when the same callback logic applies to multiple models:

```ruby
class NormalizeBlankToNil
  def self.before_save(record)
    record.attributes.each do |key, value|
      record[key] = nil if value.is_a?(String) && value.blank?
    end
  end
end

class User < ApplicationRecord
  before_save NormalizeBlankToNil
end

class Post < ApplicationRecord
  before_save NormalizeBlankToNil
end
```

**Class methods** (shown above) don't need instantiation. Use **instance methods** only if the callback object needs its own state.

### Step 10: `before_destroy` Ordering With `dependent:`

```ruby
class User < ApplicationRecord
  # ⚠️ WRONG ORDER — children deleted before callback runs
  has_many :posts, dependent: :destroy
  before_destroy :check_can_delete

  # ✅ CORRECT — use prepend: true so callback runs first
  has_many :posts, dependent: :destroy
  before_destroy :check_can_delete, prepend: true

  # ✅ ALSO CORRECT — declare callback before association
  before_destroy :check_can_delete
  has_many :posts, dependent: :destroy
end
```

## Anti-Patterns

### 1. The God Callback
```ruby
# ❌ TERRIBLE — does way too much
after_create :setup_everything

def setup_everything
  send_welcome_email
  create_default_workspace
  sync_to_stripe
  notify_admin_slack
  enqueue_onboarding_drip
end
```
→ Use a `UserRegistrationService` instead.

### 2. Conditional Spaghetti
```ruby
# ❌ Code smell — context-dependent logic
after_save :maybe_notify, if: -> { 
  saved_change_to_status? && status == "published" && !importing? && !admin_edit? 
}
```
→ Move to `PublishPostService` that explicitly calls notification.

### 3. Callback-Driven Architecture
```ruby
# ❌ "Saving a record" triggers a Rube Goldberg machine
after_save :update_cache
after_save :recalculate_totals
after_save :sync_search_index
after_save :notify_subscribers
after_save :update_analytics
```
→ Most of these belong in service objects or async jobs triggered explicitly.

### 4. Using `after_save` for External Calls
```ruby
# ❌ DANGEROUS — transaction may rollback after email is sent
after_save :send_notification_email

# ✅ SAFE — only fires after commit
after_commit :send_notification_email, on: :create
```

## Suppressing Callbacks

Use `ActiveRecord::Suppressor` to temporarily prevent saves of a specific model:

```ruby
Notification.suppress do
  User.create!(name: "Test") # Won't create notifications even if after_create does
end
```

**Use sparingly** — this is a testing/seeding tool, not production logic.

## Reference

For detailed patterns, examples, edge cases, and the complete callback lifecycle, see `reference.md` in this skill directory.
