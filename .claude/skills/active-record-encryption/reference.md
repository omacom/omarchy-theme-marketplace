# Active Record Encryption — Reference

Detailed patterns, examples, and edge cases for Active Record Encryption in Rails 7.1+.

## Table of Contents

- [Setup Deep Dive](#setup-deep-dive)
- [Deterministic vs Non-Deterministic](#deterministic-vs-non-deterministic)
- [Column Sizing Guide](#column-sizing-guide)
- [Querying Encrypted Data](#querying-encrypted-data)
- [Case Handling](#case-handling)
- [Serialized Attributes](#serialized-attributes)
- [Action Text Encryption](#action-text-encryption)
- [Key Management](#key-management)
- [Key Rotation](#key-rotation)
- [Migrating Unencrypted Data](#migrating-unencrypted-data)
- [Previous Encryption Schemes](#previous-encryption-schemes)
- [Encryption Contexts](#encryption-contexts)
- [Compression](#compression)
- [Filtering and Logging](#filtering-and-logging)
- [Fixtures and Testing](#fixtures-and-testing)
- [Custom Key Providers](#custom-key-providers)
- [Encoding](#encoding)
- [Storage Format](#storage-format)
- [Performance Considerations](#performance-considerations)
- [Common Scenarios](#common-scenarios)

---

## Setup Deep Dive

### Generating Keys

```bash
$ bin/rails db:encryption:init
Add this entry to the credentials of the target environment:

active_record_encryption:
  primary_key: YehXdfzxVKpoLvKseJMJIEGs2JxerkB8
  deterministic_key: uhtk2DYS80OweAPnMLtrV2FhYIXaceAy
  key_derivation_salt: g7Q66StqUQDQk9SJ81sWbYZXgiRogBwS
```

### What Each Key Does

| Key | Purpose | Required For |
|-----|---------|-------------|
| `primary_key` | Derives the key used for non-deterministic encryption | All encryption |
| `deterministic_key` | Derives the key used for deterministic encryption | `deterministic: true` fields only |
| `key_derivation_salt` | Salt for PBKDF2 key derivation | All encryption |

**If you don't define `deterministic_key`**, deterministic encryption is effectively disabled — any `deterministic: true` declaration will raise errors.

### Key Length Requirements

- `primary_key`: Minimum 12 bytes (recommended 32 bytes, which is what `db:encryption:init` generates)
- `key_derivation_salt`: Minimum 20 bytes (recommended 32 bytes)

### Storing in Credentials (Recommended)

```bash
# For default credentials
bin/rails credentials:edit

# For environment-specific
EDITOR=vim bin/rails credentials:edit --environment production
```

```yaml
active_record_encryption:
  primary_key: YehXdfzxVKpoLvKseJMJIEGs2JxerkB8
  deterministic_key: uhtk2DYS80OweAPnMLtrV2FhYIXaceAy
  key_derivation_salt: g7Q66StqUQDQk9SJ81sWbYZXgiRogBwS
```

### Storing via Environment Variables

```ruby
# config/application.rb
config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
```

### Per-Environment Keys

Use different keys per environment. Generate separately for development, staging, production:

```bash
RAILS_ENV=production bin/rails db:encryption:init
RAILS_ENV=staging bin/rails db:encryption:init
```

Store in environment-specific credentials files:
- `config/credentials/production.yml.enc`
- `config/credentials/staging.yml.enc`

---

## Deterministic vs Non-Deterministic

### How They Differ

**Non-deterministic (default):**
- Same plaintext → different ciphertext each time
- Uses AES-256-GCM with a random initialization vector (IV)
- Cannot be queried via SQL WHERE clauses
- More secure — resistant to frequency analysis

**Deterministic:**
- Same plaintext → same ciphertext every time
- Uses AES-256-GCM with an IV derived from HMAC-SHA256 of key + plaintext
- CAN be queried via SQL WHERE clauses
- Less secure — identical values produce identical ciphertexts (vulnerable to frequency analysis)

### When to Use Each

| Scenario | Mode | Why |
|----------|------|-----|
| SSN, medical records, notes | Non-deterministic | Never queried directly, maximum security |
| Email (login/lookup) | Deterministic | Need `find_by(email:)` for authentication |
| Phone number (lookup) | Deterministic | Need to search by phone |
| Address | Non-deterministic | Rarely queried by exact match |
| Credit card last 4 | Non-deterministic | Display only, don't query |
| API keys/tokens | Non-deterministic | Compared in app code, not SQL |
| National ID (lookup) | Deterministic | Need exact match lookups |

### Declaration Examples

```ruby
class User < ApplicationRecord
  # Non-deterministic (default) — can't query these
  encrypts :ssn
  encrypts :date_of_birth
  encrypts :medical_notes

  # Deterministic — can query these
  encrypts :email, deterministic: true
  encrypts :phone_number, deterministic: true, downcase: true
end
```

---

## Column Sizing Guide

Encrypted payloads are JSON objects with Base64-encoded ciphertext. The overhead comes from:
- JSON structure (`{"p":"...","h":{"iv":"...","at":"..."}}`)
- Base64 encoding (33% expansion)
- Encryption metadata (IV, auth tag)

### Worst-Case Overhead

With the built-in envelope encryption key provider: **~255 bytes** of additional overhead.

### Sizing Rules

For `string` columns (size defined in characters, which can be up to 4 bytes each in UTF-8):

| Content Type | Original Size | Encrypted Size Needed | Reasoning |
|-------------|---------------|----------------------|-----------|
| ASCII email | `string(255)` | `string(510)` | Original + 255 overhead |
| Short emoji | `string(255)` | `string(1020)` | 4x for non-ASCII + 255 overhead |
| Non-Western text | `string(500)` | `string(2255)` | 4x + 255 overhead |
| Long text | `text` | `text` | Overhead negligible for large payloads |

### Migration Example

```ruby
class ResizeColumnsForEncryption < ActiveRecord::Migration[7.1]
  def change
    change_column :users, :email, :string, limit: 510
    change_column :users, :phone_number, :string, limit: 510
    change_column :users, :ssn, :string, limit: 510
  end
end
```

**Pro tip:** If the field could be long or variable, just use `text` and avoid sizing headaches entirely.

---

## Querying Encrypted Data

### Deterministic Queries — What Works

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true
end

# All of these work:
User.find_by(email: "user@example.com")
User.where(email: "user@example.com")
User.where(email: ["a@b.com", "c@d.com"])
User.exists?(email: "user@example.com")
User.find_or_create_by(email: "user@example.com")
```

Rails encrypts the query parameter before sending it to the database, so the SQL contains the ciphertext:

```sql
SELECT "users".* FROM "users" WHERE "users"."email" = '{"p":"8BAc8dGX...","h":{"iv":"Ngq...","at":"1uV..."}}' LIMIT 1
```

### What Does NOT Work (Even Deterministic)

```ruby
# LIKE / pattern matching — NEVER works
User.where("email LIKE ?", "%@gmail.com")

# Range queries — NEVER works
User.where(email: "a@b.com".."z@z.com")

# ORDER BY encrypted column — meaningless (sorts by ciphertext)
User.order(:email)

# DISTINCT on encrypted column — works with deterministic only
# (same plaintext = same ciphertext)

# SQL functions — NEVER works
User.where("LOWER(email) = ?", "user@example.com")
# Use downcase: true or ignore_case: true instead
```

### Non-Deterministic — Queries Never Work

```ruby
class User < ApplicationRecord
  encrypts :ssn  # non-deterministic (default)
end

User.find_by(ssn: "123-45-6789")  # => nil ALWAYS
User.where(ssn: "123-45-6789")    # => [] ALWAYS
```

### Extended Queries (Migration Period)

When you have a mix of encrypted and unencrypted data:

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = true
config.active_record.encryption.extend_queries = true
```

With `extend_queries`, deterministic queries will search for BOTH the encrypted value AND the plaintext value, so queries work during migration.

---

## Case Handling

### `downcase: true`

Converts the value to lowercase before encryption. **Original case is permanently lost.**

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true, downcase: true
end

user = User.create!(email: "John@Example.COM")
user.email  # => "john@example.com" (lowercased)

User.find_by(email: "JOHN@EXAMPLE.COM")  # => finds the user
User.find_by(email: "john@example.com")  # => finds the user
```

### `ignore_case: true`

Preserves original case but queries case-insensitively. **Requires an additional column.**

```ruby
class Label < ApplicationRecord
  encrypts :name, deterministic: true, ignore_case: true
end
```

You MUST add a column named `original_<attribute_name>`:

```ruby
class AddOriginalNameToLabels < ActiveRecord::Migration[7.1]
  def change
    add_column :labels, :original_name, :string, limit: 510
  end
end
```

How it works:
- `original_name` column stores the encrypted value with original case
- `name` column stores the encrypted downcased value (for querying)
- Reading `label.name` returns the original case from `original_name`
- Querying `Label.find_by(name: "FOO")` searches the downcased `name` column

### Uniqueness with Case Handling

```ruby
class User < ApplicationRecord
  validates :email, uniqueness: true
  encrypts :email, deterministic: true, downcase: true
end
```

**⚠️ Do NOT use `uniqueness: { case_sensitive: false }`.** It doesn't work with encrypted fields. Use `downcase: true` on `encrypts` instead.

---

## Serialized Attributes

### Declaration Order Matters

```ruby
# ✅ CORRECT — serialize first, then encrypts
class Article < ApplicationRecord
  serialize :metadata, type: Hash
  encrypts :metadata
end

# ❌ WRONG — encrypts before serialize
class Article < ApplicationRecord
  encrypts :metadata
  serialize :metadata, type: Hash  # This will NOT work correctly
end
```

### Custom Message Serializer

For types that aren't natively serializable as strings:

```ruby
class Article < ApplicationRecord
  encrypts :metadata, message_serializer: MyCustomSerializer.new
end
```

**Security warning:** Custom serializers must NOT use `Marshal`, `YAML.load`, or `JSON.load`. Use `YAML.safe_load` or `JSON.parse` to prevent deserialization attacks.

---

## Action Text Encryption

```ruby
class Message < ApplicationRecord
  has_rich_text :content, encrypted: true
end
```

Key points:
- Always uses non-deterministic encryption
- Individual encryption options (like `deterministic: true`) are NOT supported
- Uses the global encryption configuration
- Fixtures go in `fixtures/action_text/encrypted_rich_texts.yml`

---

## Key Management

### Default Key Provider: DerivedSecretKeyProvider

The default provider derives encryption keys from the `primary_key` using PBKDF2:

```ruby
# This is what Rails configures automatically from your credentials
ActiveRecord::Encryption::DerivedSecretKeyProvider.new(["your_primary_key"])
```

### Envelope Encryption Key Provider

Generates a random data-key per record, then encrypts that data-key with the primary key:

```ruby
# config/application.rb
config.active_record.encryption.key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
```

Pros: Each record has a unique key (more secure)
Cons: Slightly larger payloads (encrypted data-key stored alongside)

### Per-Attribute Key Provider

```ruby
class Article < ApplicationRecord
  encrypts :summary, key_provider: ArticleKeyProvider.new
end
```

### Per-Attribute Static Key

```ruby
class Article < ApplicationRecord
  encrypts :summary, key: ENV["ARTICLE_SUMMARY_KEY"]
end
```

### Storing Key References

Stores a key identifier in the encrypted payload for faster decryption (avoids trying all keys):

```ruby
config.active_record.encryption.store_key_references = true
```

Trade-off: Slightly larger encrypted payloads, but faster decryption when using multiple keys.

---

## Key Rotation

### Non-Deterministic Key Rotation

Add new keys to the list. The **last key** encrypts new data; **all keys** can decrypt:

```yaml
# config/credentials.yml.enc
active_record_encryption:
  primary_key:
    - old_key_that_can_still_decrypt    # Previous key
    - brand_new_active_key              # Current key (encrypts new data)
  key_derivation_salt: same_salt_as_before
```

### Re-Encrypting Data After Rotation

```ruby
# Re-encrypt all users with the current (newest) key
User.find_each do |user|
  user.encrypt
rescue => e
  Rails.logger.error("Failed to re-encrypt user #{user.id}: #{e.message}")
end
```

After re-encryption, you can safely remove old keys from the list.

### Deterministic Key Rotation — NOT SUPPORTED

**You cannot rotate keys for deterministic encryption.** The whole point of deterministic encryption is that the same plaintext always produces the same ciphertext. Changing the key breaks this guarantee and all queries will fail.

If you absolutely must change deterministic keys:
1. Decrypt all data
2. Change the key
3. Re-encrypt all data
4. This is effectively a full data migration, not a rotation

---

## Migrating Unencrypted Data

### Full Migration Workflow

**Step 1: Add encryption config (coexistence mode)**

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = true
config.active_record.encryption.extend_queries = true
```

**Step 2: Resize columns if needed**

```ruby
class ResizeColumnsForEncryption < ActiveRecord::Migration[7.1]
  def change
    change_column :users, :email, :string, limit: 510
    change_column :users, :ssn, :string, limit: 510
  end
end
```

**Step 3: Add `encrypts` declarations to models**

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true
  encrypts :ssn
end
```

**Step 4: Deploy — reads still work for unencrypted data**

At this point, new records are encrypted, old records are still readable.

**Step 5: Encrypt existing data**

```ruby
# Rake task or script
User.find_each do |user|
  user.encrypt
rescue => e
  Rails.logger.error("Encryption failed for User##{user.id}: #{e.message}")
end
```

**Step 6: Verify all data is encrypted**

```ruby
unencrypted_count = 0
User.find_each do |user|
  unless user.encrypted_attribute?(:email)
    unencrypted_count += 1
    puts "User #{user.id} has unencrypted email"
  end
end
puts "#{unencrypted_count} users still unencrypted"
```

**Step 7: Remove coexistence config**

```ruby
# Remove these lines once all data is encrypted:
# config.active_record.encryption.support_unencrypted_data = true
# config.active_record.encryption.extend_queries = true
```

---

## Previous Encryption Schemes

When changing encryption properties on an existing encrypted attribute.

### Global Previous Schemes

```ruby
# config/application.rb
config.active_record.encryption.previous = [{ key_provider: MyOldKeyProvider.new }]
```

### Per-Attribute Previous Schemes

```ruby
class Article < ApplicationRecord
  # Changed from non-deterministic to deterministic
  encrypts :title, deterministic: true, previous: { deterministic: false }
end
```

**Requires `extend_queries`:**

```ruby
config.active_record.encryption.extend_queries = true
```

### How Previous Schemes Work

- **Reading:** Rails tries the current scheme first; if decryption fails, it tries previous schemes in order.
- **Querying (deterministic):** Rails generates ciphertexts for both current AND previous schemes, adding them all to the WHERE clause.
- **Writing:** Always uses the current scheme.

### Deterministic Scheme Changes — Special Behavior

- **Non-deterministic:** New data always encrypted with the newest (current) scheme.
- **Deterministic:** New data encrypted with the **oldest** scheme by default (for consistency).

To force deterministic to use the newest scheme:

```ruby
class Article < ApplicationRecord
  encrypts :title, deterministic: { fixed: false }
end
```

---

## Encryption Contexts

### Running Code Without Encryption

```ruby
# Reads return ciphertext, writes store plaintext
ActiveRecord::Encryption.without_encryption do
  raw = User.first.email  # Returns the JSON ciphertext string
  puts raw
end
```

### Protecting Encrypted Data (Read-Only Mode)

```ruby
# Can read (decrypted), but writes are blocked
ActiveRecord::Encryption.protecting_encrypted_data do
  user = User.first
  puts user.email          # Works — returns decrypted value
  user.update(email: "x")  # Raises error — can't overwrite
end
```

Useful in Rails console when you want to inspect but not accidentally modify encrypted data.

### Custom Encryption Context

```ruby
ActiveRecord::Encryption.with_encryption_context(
  encryptor: MyCustomEncryptor.new,
  key_provider: MyKeyProvider.new
) do
  # All encryption in this block uses the custom components
end
```

### Per-Attribute Context Override

```ruby
class Article < ApplicationRecord
  encrypts :title, encryptor: MySpecialEncryptor.new
end
```

---

## Compression

Enabled by default. Uses Zlib. Applied when payload exceeds ~140 bytes.

### Disabling Compression

```ruby
class Article < ApplicationRecord
  encrypts :content, compress: false
end
```

### Custom Compressor

```ruby
require "zstd-ruby"

module ZstdCompressor
  def self.deflate(data)
    Zstd.compress(data)
  end

  def self.inflate(data)
    Zstd.decompress(data)
  end
end

class User < ApplicationRecord
  encrypts :notes, compressor: ZstdCompressor
end

# Or globally:
config.active_record.encryption.compressor = ZstdCompressor
```

---

## Filtering and Logging

Encrypted attributes are **automatically added to `filter_parameters`**, so they show as `[FILTERED]` in logs.

### Disabling Auto-Filtering

```ruby
config.active_record.encryption.add_to_filter_parameters = false
```

### Excluding Specific Attributes from Filtering

```ruby
config.active_record.encryption.excluded_from_filter_parameters = [:catchphrase]
```

### Filter Parameter Naming

Rails prefixes with the model name: `User#email` → filter parameter `user.email`.

### Console Display

Encrypted attributes show as `[FILTERED]` in the Rails console:

```
#<User id: 1, email: "[FILTERED]", created_at: ...>
```

---

## Fixtures and Testing

### Enable Fixture Encryption

```ruby
# config/environments/test.rb
Rails.application.configure do
  config.active_record.encryption.encrypt_fixtures = true
end
```

### Writing Fixtures

With `encrypt_fixtures = true`, write plain text — Rails encrypts automatically:

```yaml
# test/fixtures/users.yml
admin:
  email: "admin@example.com"
  ssn: "123-45-6789"
  name: "Admin User"
```

### Action Text Fixtures

Place encrypted Action Text fixtures in:
```
test/fixtures/action_text/encrypted_rich_texts.yml
```

### Testing Encrypted Attributes

```ruby
class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
  end

  test "email is encrypted in database" do
    assert @user.encrypted_attribute?(:email)
  end

  test "can read decrypted email" do
    assert_equal "admin@example.com", @user.email
  end

  test "ciphertext is not the plaintext" do
    ciphertext = @user.ciphertext_for(:email)
    refute_equal "admin@example.com", ciphertext
    assert ciphertext.start_with?("{")  # JSON format
  end

  test "deterministic email is queryable" do
    found = User.find_by(email: "admin@example.com")
    assert_equal @user, found
  end

  test "non-deterministic ssn is not queryable" do
    # This is expected behavior — not a bug
    assert_nil User.find_by(ssn: "123-45-6789")
  end
end
```

---

## Custom Key Providers

### Interface

```ruby
class MyKeyProvider
  # Returns a single ActiveRecord::Encryption::Key for encrypting
  def encryption_key
    ActiveRecord::Encryption::Key.new("32-byte-key-here-padded-to-size!")
  end

  # Returns an array of Keys to try when decrypting
  def decryption_keys(encrypted_message)
    [
      ActiveRecord::Encryption::Key.new("current-key..."),
      ActiveRecord::Encryption::Key.new("previous-key...")
    ]
  end
end
```

### Per-Attribute Usage

```ruby
class Article < ApplicationRecord
  encrypts :summary, key_provider: ArticleKeyProvider.new
end
```

### Global Usage

```ruby
# config/initializers/encryption.rb
ActiveRecord::Encryption.key_provider = MyKeyProvider.new
```

### Example: AWS KMS Key Provider

```ruby
class KmsKeyProvider
  def encryption_key
    data_key = Aws::KMS::Client.new.generate_data_key(key_id: ENV["KMS_KEY_ID"], key_spec: "AES_256")
    key = ActiveRecord::Encryption::Key.new(data_key.plaintext)
    key.public_tags.encrypted_data_key = Base64.encode64(data_key.ciphertext_blob)
    key
  end

  def decryption_keys(encrypted_message)
    encrypted_data_key = Base64.decode64(encrypted_message.headers.encrypted_data_key)
    plaintext = Aws::KMS::Client.new.decrypt(ciphertext_blob: encrypted_data_key).plaintext
    [ActiveRecord::Encryption::Key.new(plaintext)]
  end
end
```

---

## Encoding

### Deterministic Encryption Forces UTF-8

By default, deterministic encryption forces UTF-8 encoding to ensure consistent ciphertexts:

```ruby
# Same string, different encoding → same ciphertext (because forced to UTF-8)
"hello".encode("ASCII")   # → encrypted as UTF-8
"hello".encode("UTF-8")   # → same ciphertext
```

### Changing the Forced Encoding

```ruby
config.active_record.encryption.forced_encoding_for_deterministic_encryption = Encoding::US_ASCII
```

### Disabling Forced Encoding

```ruby
config.active_record.encryption.forced_encoding_for_deterministic_encryption = nil
```

**Warning:** Disabling this means the same string with different encodings could produce different ciphertexts, breaking queries.

### Non-Deterministic Preserves Encoding

Non-deterministic encryption automatically preserves the original encoding.

---

## Storage Format

Encrypted values are stored as JSON:

```json
{
  "p": "oq+RFYW8CucALxnJ6ccx",
  "h": {
    "iv": "3nrJAIYcN1+YcGMQ",
    "at": "JBsw7uB90yAyWbQ8E3krjg=="
  }
}
```

| Key | Purpose |
|-----|---------|
| `p` | Payload — Base64-encoded, compressed, encrypted ciphertext |
| `h.iv` | Initialization vector |
| `h.at` | Authentication tag (integrity check) |

With envelope encryption, additional keys appear for the encrypted data key.

---

## Performance Considerations

### Encryption Overhead

- **CPU:** Negligible for individual operations. AES-256-GCM is hardware-accelerated on modern CPUs.
- **Storage:** ~255 bytes overhead per field for short values. Compression can offset this for larger payloads.
- **Query performance:** Deterministic queries work like normal string equality. No special index needed beyond a regular B-tree index.
- **Batch operations:** `find_each` + `encrypt` for re-encryption. Consider batching in background jobs for large tables.

### Tips

1. **Use `text` columns** for encrypted fields when possible — avoids sizing headaches entirely.
2. **Enable `store_key_references`** if using multiple keys — avoids trying each key during decryption.
3. **Run re-encryption in background jobs** for tables with millions of rows.
4. **Don't encrypt columns you ORDER BY or GROUP BY** — the results will be meaningless (sorted by ciphertext).

---

## Common Scenarios

### Encrypting User PII

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true, downcase: true
  encrypts :phone_number, deterministic: true
  encrypts :ssn
  encrypts :date_of_birth
  encrypts :address

  validates :email, uniqueness: true
end
```

### Multi-Tenant Encryption with Per-Tenant Keys

```ruby
class TenantKeyProvider
  def initialize(tenant)
    @tenant = tenant
  end

  def encryption_key
    ActiveRecord::Encryption::Key.new(@tenant.encryption_key)
  end

  def decryption_keys(encrypted_message)
    [ActiveRecord::Encryption::Key.new(@tenant.encryption_key)]
  end
end

class Document < ApplicationRecord
  encrypts :content, key_provider: ->(record) { TenantKeyProvider.new(record.tenant) }
end
```

### Encrypting Existing Data in a Background Job

```ruby
class EncryptUserDataJob < ApplicationJob
  queue_as :low_priority

  def perform(user_ids)
    User.where(id: user_ids).find_each do |user|
      user.encrypt unless user.encrypted_attribute?(:email)
    rescue => e
      Rails.logger.error("Encryption failed for User##{user.id}: #{e.message}")
      Sentry.capture_exception(e, extra: { user_id: user.id })
    end
  end
end

# Enqueue in batches
User.in_batches(of: 1000) do |batch|
  EncryptUserDataJob.perform_later(batch.pluck(:id))
end
```

### API Keys with Non-Deterministic Encryption + Digest

When you need to look up by a value but want non-deterministic encryption:

```ruby
class ApiKey < ApplicationRecord
  encrypts :token  # Non-deterministic — maximum security

  before_create :set_token_digest

  def self.find_by_token(plain_token)
    find_by(token_digest: Digest::SHA256.hexdigest(plain_token))
  end

  private

  def set_token_digest
    self.token_digest = Digest::SHA256.hexdigest(token)
  end
end
```

This gives you:
- Non-deterministic encryption for the actual token (more secure at rest)
- A deterministic SHA256 digest column for lookups
- Best of both worlds

### Conditional Encryption During Migration

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true

  # During migration, check if data is already encrypted
  def needs_encryption?
    !encrypted_attribute?(:email)
  end
end
```
