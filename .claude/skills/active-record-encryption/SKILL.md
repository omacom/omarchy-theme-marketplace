---
name: active-record-encryption
description: Expert guidance for encrypting sensitive data at rest using Active Record Encryption in Rails. Use when adding encryption to model attributes, rotating keys, migrating unencrypted data, querying encrypted fields, or protecting PII. Triggers on "encryption", "encrypt", "encrypts", "encrypted attribute", "at-rest encryption", "field encryption", "key rotation", "deterministic encryption", "PII", "sensitive data", "encrypt column", "encrypts macro".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails db:encryption:*), Bash(bin/rails credentials:*), Bash(bin/rails console), Bash(bundle exec rails db:encryption:*)
---

# Active Record Encryption Expert

Encrypt sensitive data at the application level using Rails' built-in Active Record Encryption.

## Philosophy

**Core Principles:**
1. **Encrypt only what needs it** — Encryption adds complexity and storage overhead. Be deliberate.
2. **Deterministic only when you must query** — Non-deterministic is more secure. Default to it.
3. **Keys belong in credentials, not code** — Never commit encryption keys. Period.
4. **Plan migration before encrypting** — Existing unencrypted data needs a migration strategy.
5. **Test with encryption enabled** — Fixtures need `encrypt_fixtures: true` or tests will break.

**Decision Matrix:**
```
Need to query/find_by this field?
  YES → deterministic: true
  NO  → default (non-deterministic)

Need uniqueness validation?
  YES → deterministic: true (+ downcase/ignore_case if case-insensitive)

Need to preserve case but query case-insensitively?
  YES → deterministic: true, ignore_case: true (adds original_<column> column)

Just protecting data at rest (logs, backups)?
  YES → default (non-deterministic) is perfect
```

## When To Use This Skill

- Adding `encrypts` declarations to model attributes
- Setting up encryption keys for the first time
- Migrating existing unencrypted data to encrypted
- Rotating encryption keys
- Querying deterministically encrypted attributes
- Encrypting Action Text content
- Debugging encryption-related errors (decryption failures, query mismatches)
- Understanding deterministic vs non-deterministic trade-offs

## Critical Mistakes to Avoid

> **🚨 These are the mistakes agents make most often. Read before writing any code.**

1. **Querying non-deterministic fields** — `Model.find_by(field: value)` only works with `deterministic: true`. Non-deterministic encryption produces different ciphertexts each time, so the database can't match against them.

2. **Forgetting to generate/configure keys** — `encrypts :email` does nothing useful without running `rails db:encryption:init` and storing keys in credentials. You'll get `ActiveRecord::Encryption::Errors::Configuration` errors.

3. **Encrypting fields that need indexing without deterministic mode** — Database indexes on non-deterministic columns are useless. If you need a unique index, use `deterministic: true`.

4. **Not planning for existing data** — Adding `encrypts` to a model with existing rows breaks reads because Rails tries to decrypt plaintext values. Enable `support_unencrypted_data` during migration.

5. **Using `ignore_case: true` without adding the column** — This option requires an `original_<column_name>` column in the database. Missing it = crash.

6. **Declaring `serialize` AFTER `encrypts`** — For serialized attributes, `serialize` must come before `encrypts` in the model. Rails processes these declarations in order, and encryption needs to wrap the already-serialized value.

7. **Trying to rotate keys for deterministic encryption** — Key rotation isn't supported for deterministic encryption because the same plaintext must always produce the same ciphertext (that's how queries work). Changing the key silently breaks all lookups.

8. **Undersizing string columns** — Encrypted payloads are larger. A `string(255)` email column needs at least `string(510)` when encrypted. See reference.md for sizing guide.

## Instructions

### Step 1: Generate and Store Keys

**Start here.** Without keys configured, `encrypts` declarations silently produce configuration errors at runtime.

```bash
bin/rails db:encryption:init
```

This outputs three values. Store them in credentials:

```bash
bin/rails credentials:edit
```

```yaml
active_record_encryption:
  primary_key: YehXdfzxVKpoLvKseJMJIEGs2JxerkB8
  deterministic_key: uhtk2DYS80OweAPnMLtrV2FhYIXaceAy
  key_derivation_salt: g7Q66StqUQDQk9SJ81sWbYZXgiRogBwS
```

**Alternative: Environment variables** (12-factor apps):

```ruby
# config/application.rb
config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
```

**Verify keys are configured:**

```bash
bin/rails runner "puts ActiveRecord::Encryption.config.primary_key.present?"
# Should print: true
```

### Step 2: Check Existing Patterns

**Search the codebase first** to understand existing encryption patterns:

```bash
# Find existing encryption declarations
rg "encrypts :" app/models/

# Check for existing encryption config
rg "active_record.encryption" config/
rg "active_record_encryption" config/credentials/

# Check column sizes for fields you plan to encrypt
bin/rails runner "ActiveRecord::Base.connection.columns('users').each { |c| puts \"#{c.name}: #{c.type}(#{c.limit})\" }"
```

**Match existing project conventions** — if they're using env vars, use env vars. If credentials, use credentials.

### Step 3: Declare Encrypted Attributes

**Non-deterministic (default — most secure):**

```ruby
class User < ApplicationRecord
  encrypts :ssn
  encrypts :medical_notes
end
```

**Deterministic (queryable):**

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true
  encrypts :phone, deterministic: true, downcase: true
end
```

**Action Text:**

```ruby
class Message < ApplicationRecord
  has_rich_text :content, encrypted: true
end
```

**With serialized attributes (order matters!):**

```ruby
class Article < ApplicationRecord
  serialize :metadata, type: Hash    # FIRST
  encrypts :metadata                  # SECOND
end
```

### Step 4: Handle Column Sizing

**Before encrypting, check and resize columns if needed.**

| Original Column | Encrypted Size Needed |
|-----------------|----------------------|
| `string(255)` ASCII | `string(510)` |
| `string(255)` Unicode | `string(1275)` |
| `string(500)` non-Western | `string(2255)` |
| `text` | `text` (no change needed) |

Generate a migration if column is too small:

```ruby
class ResizeEmailForEncryption < ActiveRecord::Migration[7.1]
  def change
    change_column :users, :email, :string, limit: 510
  end
end
```

### Step 5: Migrate Existing Unencrypted Data

**If the table already has data, plan the migration.** Without this, Rails tries to decrypt plaintext rows and raises `Decryption` errors.

**Phase 1: Enable coexistence**

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = true
config.active_record.encryption.extend_queries = true
```

**Phase 2: Encrypt existing records** (run as a task or migration)

```ruby
# lib/tasks/encryption.rake
namespace :encryption do
  desc "Encrypt existing user data"
  task encrypt_users: :environment do
    User.find_each do |user|
      user.encrypt
    rescue => e
      Rails.logger.error "Failed to encrypt user #{user.id}: #{e.message}"
    end
  end
end
```

```bash
bin/rails encryption:encrypt_users
```

**Phase 3: Verify and disable coexistence**

```ruby
# Verify all records are encrypted
User.find_each do |user|
  unless user.encrypted_attribute?(:email)
    puts "User #{user.id} still unencrypted"
  end
end
```

Once all data is encrypted, remove the coexistence config:

```ruby
# Remove these lines:
# config.active_record.encryption.support_unencrypted_data = true
# config.active_record.encryption.extend_queries = true
```

### Step 6: Configure Key Rotation (Non-Deterministic Only)

**Key rotation only works for non-deterministic encryption.** Deterministic fields must keep their original key — changing it breaks all queries because ciphertexts no longer match.

Add new key to the list — last key encrypts, all keys decrypt:

```yaml
# credentials
active_record_encryption:
  primary_key:
    - old_key_abc123           # Can still decrypt
    - new_key_xyz789           # Active — encrypts new data
  key_derivation_salt: g7Q66StqUQDQk9SJ81sWbYZXgiRogBwS
```

Re-encrypt existing data with the new key:

```ruby
User.find_each(&:encrypt)
```

After re-encryption, remove old keys.

### Step 7: Configure Test Environment

**Add to `config/environments/test.rb`:**

```ruby
Rails.application.configure do
  config.active_record.encryption.encrypt_fixtures = true
end
```

Without this, fixture values won't be encrypted and reads will fail.

**If migrating data, enable coexistence in test too:**

```ruby
config.active_record.encryption.support_unencrypted_data = true
config.active_record.encryption.extend_queries = true
```

### Step 8: Handle Querying Correctly

**Deterministic — queries work naturally:**

```ruby
# These work with deterministic: true
User.find_by(email: "user@example.com")
User.where(email: "user@example.com")
```

**Non-deterministic — queries are impossible:**

```ruby
# These can't work with non-deterministic encryption — each encryption
# produces a different ciphertext, so the DB can't match against it
User.find_by(ssn: "123-45-6789")  # => nil (always)
User.where(ssn: "123-45-6789")    # => empty (always)
```

**If you need to find by a non-deterministic field, you have two options:**
1. Switch to `deterministic: true` (less secure)
2. Add a separate deterministic digest/hash column for lookups

### Step 9: Uniqueness and Case Sensitivity

**Unique validations require deterministic encryption:**

```ruby
class User < ApplicationRecord
  validates :email, uniqueness: true
  encrypts :email, deterministic: true, downcase: true
end
```

**Don't use `case_sensitive: false` on the validation** — it doesn't work with encrypted fields because the database sees ciphertext, not plaintext. Use `downcase: true` or `ignore_case: true` on `encrypts` instead, which handles case normalization before encryption.

**`downcase: true`** — Original case is lost. Simple.

**`ignore_case: true`** — Preserves original case but requires an extra column:

```ruby
# Migration needed:
add_column :labels, :original_name, :string

# Model:
class Label < ApplicationRecord
  encrypts :name, deterministic: true, ignore_case: true
end
```

## Quick Reference

### encrypts Options

| Option | Default | Purpose |
|--------|---------|---------|
| `deterministic:` | `false` | Enable queryable encryption |
| `downcase:` | `false` | Lowercase before encrypting (deterministic only) |
| `ignore_case:` | `false` | Case-insensitive queries, preserves original (needs `original_` column) |
| `key_provider:` | global | Custom key provider for this attribute |
| `key:` | nil | Specific encryption key for this attribute |
| `previous:` | nil | Previous encryption scheme(s) for migration |
| `compress:` | `true` | Enable payload compression |
| `compressor:` | `Zlib` | Custom compression algorithm |
| `message_serializer:` | default | Custom serializer for the encrypted payload |

### Configuration Options

```ruby
# config/application.rb
config.active_record.encryption.primary_key = "..."
config.active_record.encryption.deterministic_key = "..."
config.active_record.encryption.key_derivation_salt = "..."
config.active_record.encryption.support_unencrypted_data = false  # true during migration
config.active_record.encryption.extend_queries = false             # true during migration
config.active_record.encryption.encrypt_fixtures = false           # true in test env
config.active_record.encryption.add_to_filter_parameters = true    # auto-filter in logs
config.active_record.encryption.store_key_references = false       # faster decryption, larger payload
config.active_record.encryption.forced_encoding_for_deterministic_encryption = Encoding::UTF_8
```

### Programmatic API

```ruby
record.encrypt                          # Encrypt/re-encrypt all encryptable attributes
record.decrypt                          # Decrypt all encryptable attributes
record.encrypted_attribute?(:field)     # Check if attribute is currently encrypted
record.ciphertext_for(:field)           # Read raw ciphertext

# Run code without encryption (reads return ciphertext, writes store plaintext)
ActiveRecord::Encryption.without_encryption { ... }

# Run code that can read encrypted data but can't overwrite it
ActiveRecord::Encryption.protecting_encrypted_data { ... }
```

### Common Error → Fix

| Error | Cause | Fix |
|-------|-------|-----|
| `ActiveRecord::Encryption::Errors::Configuration` | Keys not configured | Run `rails db:encryption:init`, store in credentials |
| `ActiveRecord::Encryption::Errors::Decryption` | Wrong key or corrupted data | Check key config; enable `support_unencrypted_data` during migration |
| Query returns `nil` for existing data | Querying non-deterministic field | Add `deterministic: true` to `encrypts` declaration |
| `undefined column 'original_X'` | Using `ignore_case: true` without migration | Add `original_<column>` column via migration |
| Fixture tests fail | Fixtures not encrypted | Set `encrypt_fixtures = true` in test config |
| Serialized attribute silently broken | Wrong declaration order | Put `serialize` BEFORE `encrypts` |

## Debugging Tips

```ruby
# Check if encryption is properly configured
bin/rails runner "pp ActiveRecord::Encryption.config"

# Check if a specific record's attribute is encrypted
bin/rails runner "puts User.first.encrypted_attribute?(:email)"

# Read raw ciphertext
bin/rails runner "puts User.first.ciphertext_for(:email)"

# Temporarily disable encryption to see raw database values
ActiveRecord::Encryption.without_encryption do
  puts User.first.read_attribute(:email)
end

# Check what's actually stored in the database
bin/rails runner "puts ActiveRecord::Base.connection.select_value(\"SELECT email FROM users LIMIT 1\")"
```

## Anti-Patterns to Avoid

1. **Encrypting everything** — Only encrypt genuinely sensitive fields (PII, financial data, health info). Encrypting `name` or `created_at` adds overhead for no security gain.
2. **Using deterministic when non-deterministic suffices** — Deterministic is less secure. Only use it when you need to query by that field.
3. **Forgetting the migration plan** — Adding `encrypts` to a model with existing data without `support_unencrypted_data` will crash reads.
4. **Storing keys in the repo** — Not in config files, not in seeds, not in ENV defaults in code. Credentials or real env vars only.
5. **Skipping column resizing** — Encrypted data is larger. Undersized columns = truncation = data loss.
6. **Testing without `encrypt_fixtures`** — Fixtures load raw YAML values. Without encryption in test, comparisons break.
7. **Rotating deterministic keys** — This silently breaks all queries. Deterministic fields must keep their original key.
8. **Using `case_sensitive: false` on validations** — This doesn't work with encrypted fields. Use `downcase: true` or `ignore_case: true` on `encrypts`.
