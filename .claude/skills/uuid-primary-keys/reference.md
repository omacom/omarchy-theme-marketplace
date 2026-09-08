# UUID Primary Keys — Reference

Detailed patterns, edge cases, and implementation details for UUID primary keys in Rails.

## Table of Contents

- [UUIDv7 Deep Dive](#uuidv7-deep-dive)
- [Base36 Encoding](#base36-encoding)
- [Complete SQLite Setup (Copy-Paste Ready)](#complete-sqlite-setup)
- [PostgreSQL Setup Details](#postgresql-setup-details)
- [Migration Patterns](#migration-patterns)
- [Testing Patterns](#testing-patterns)
- [Converting Existing Apps](#converting-existing-apps)
- [Multi-Database Considerations](#multi-database-considerations)
- [Performance](#performance)
- [Edge Cases and Gotchas](#edge-cases-and-gotchas)

---

## UUIDv7 Deep Dive

### Structure

UUIDv7 (RFC 9562) encodes a Unix timestamp in the first 48 bits:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         unix_ts_ms (32 bits)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          unix_ts_ms (16 bits) |  ver  |   rand_a (12 bits)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|var|                       rand_b (62 bits)                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          rand_b (continued)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- **48-bit timestamp**: Millisecond precision Unix epoch
- **4-bit version**: Always `0111` (7)
- **12-bit rand_a**: Random bits for sub-millisecond ordering
- **2-bit variant**: Always `10`
- **62-bit rand_b**: Random bits

### Ruby Generation

```ruby
# Ruby 3.3+ (stdlib)
SecureRandom.uuid_v7
# => "019533c0-cf4c-7c67-bfad-b7bc2832e3c5"

# Extracting timestamp from UUIDv7
def uuid_v7_timestamp(uuid)
  hex = uuid.delete("-")
  ms = hex[0..11].to_i(16)
  Time.at(ms / 1000.0)
end

uuid = SecureRandom.uuid_v7
uuid_v7_timestamp(uuid)
# => 2025-01-15 10:30:45 +0000
```

### Ordering Guarantees

UUIDs generated in the same millisecond have random sub-millisecond bits. Within a single process, `SecureRandom.uuid_v7` provides monotonic ordering. Across processes/machines, ordering is guaranteed to millisecond precision.

```ruby
# These are correctly ordered (same millisecond, monotonic within process)
a = SecureRandom.uuid_v7
b = SecureRandom.uuid_v7
a < b  # => true (virtually always, within same process)
```

---

## Base36 Encoding

### Why Base36?

| Format | Length | Chars | Case-sensitive | URL-safe |
|--------|--------|-------|----------------|----------|
| Standard UUID | 36 | `0-9a-f-` | No | Yes (with encoding) |
| Hex (no dashes) | 32 | `0-9a-f` | No | Yes |
| Base36 | 25 | `0-9a-z` | No | Yes |
| Base62 | 22 | `0-9a-zA-Z` | Yes | Yes |
| Base64url | 22 | `0-9a-zA-Z_-` | Yes | Yes |

Base36 is the sweet spot: shorter than hex, case-insensitive, no special characters, human-typeable.

### Conversion Functions

```ruby
module UuidBase36
  BASE36_LENGTH = 25

  def self.encode(uuid_hex)
    # Remove dashes if present
    hex = uuid_hex.delete("-")
    hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
  end

  def self.decode(base36)
    hex = base36.to_i(36).to_s(16).rjust(32, "0")
    # Optionally format with dashes:
    "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
  end

  def self.generate
    encode(SecureRandom.uuid_v7.delete("-"))
  end
end

UuidBase36.generate
# => "0k5p9qi1v8j3h6m2n4b7x"

UuidBase36.encode("019533c0-cf4c-7c67-bfad-b7bc2832e3c5")
# => "00bh5w1mwkfkf5xtdbyc2nerp"

UuidBase36.decode("00bh5w1mwkfkf5xtdbyc2nerp")
# => "019533c0-cf4c-7c67-bfad-b7bc2832e3c5"
```

### Using Base36 with PostgreSQL

If you want base36 URLs with PostgreSQL (native UUID storage), add a virtual attribute:

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def short_id
    return nil unless id
    hex = id.delete("-")
    hex.to_i(16).to_s(36).rjust(25, "0")
  end

  def self.find_by_short_id(short_id)
    hex = short_id.to_i(36).to_s(16).rjust(32, "0")
    uuid = "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
    find_by(id: uuid)
  end
end
```

---

## Complete SQLite Setup

Copy-paste ready. Two files, that's it.

### File 1: lib/rails_ext/active_record_uuid_type.rb

```ruby
# frozen_string_literal: true

module ActiveRecord
  module Type
    class Uuid < Binary
      BASE36_LENGTH = 25

      class << self
        def generate
          uuid = SecureRandom.uuid_v7
          hex = uuid.delete("-")
          hex_to_base36(hex)
        end

        def hex_to_base36(hex)
          hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
        end

        def base36_to_hex(base36)
          base36.to_s.to_i(36).to_s(16).rjust(32, "0")
        end
      end

      def serialize(value)
        return unless value
        binary = Uuid.base36_to_hex(value).scan(/../).map(&:hex).pack("C*")
        super(binary)
      end

      def deserialize(value)
        return unless value
        hex = value.to_s.unpack1("H*")
        Uuid.hex_to_base36(hex)
      end

      def cast(value)
        value
      end
    end
  end
end

ActiveRecord::Type.register(:uuid, ActiveRecord::Type::Uuid, adapter: :sqlite3)
```

### File 2: config/initializers/uuid_primary_keys.rb

```ruby
# frozen_string_literal: true

require_relative "../../lib/rails_ext/active_record_uuid_type"

module UuidPrimaryKeyDefault
  def load_schema!
    define_uuid_primary_key_pending_default
    super
  end

  private

  def define_uuid_primary_key_pending_default
    if uuid_primary_key?
      pending_attribute_modifications << PendingUuidDefault.new(primary_key)
    end
  rescue ActiveRecord::StatementInvalid
  end

  def uuid_primary_key?
    table_name && primary_key &&
      schema_cache.columns_hash(table_name)[primary_key]&.type == :uuid
  end

  PendingUuidDefault = Struct.new(:name) do
    def apply_to(attribute_set)
      attribute_set[name] = attribute_set[name].with_user_default(-> { ActiveRecord::Type::Uuid.generate })
    end
  end
end

module SqliteUuidAdapter
  extend ActiveSupport::Concern

  def lookup_cast_type(sql_type)
    sql_type == "blob(16)" ? ActiveRecord::Type.lookup(:uuid, adapter: :sqlite3) : super
  end

  def fetch_type_metadata(sql_type)
    if sql_type == "blob(16)"
      ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        sql_type: sql_type, type: :uuid, limit: 16
      )
    else
      super
    end
  end

  class_methods do
    def native_database_types
      @native_database_types_with_uuid ||= super.merge(uuid: { name: "blob", limit: 16 })
    end
  end
end

module SchemaDumperUuidType
  def schema_type(column)
    column.sql_type == "blob(16)" ? :uuid : super
  end
end

module TableDefinitionUuidSupport
  def uuid(name, **options)
    column(name, :uuid, **options)
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.prepend(UuidPrimaryKeyDefault)
  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionUuidSupport)
end

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteUuidAdapter)
  ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.prepend(SchemaDumperUuidType)
end

if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
  unless ActiveRecord::ConnectionAdapters::SQLite3Adapter.ancestors.include?(SqliteUuidAdapter)
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteUuidAdapter)
  end
end

if defined?(ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper)
  unless ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.ancestors.include?(SchemaDumperUuidType)
    ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.prepend(SchemaDumperUuidType)
  end
end
```

### File 3: app/models/application_record.rb (add callback)

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_create :ensure_uuid_primary_key

  private

  def ensure_uuid_primary_key
    pk = self.class.primary_key
    return unless pk
    column = self.class.columns_hash[pk]
    return unless column&.type == :uuid
    self[pk] ||= ActiveRecord::Type::Uuid.generate
  end
end
```

### File 4: config/initializers/generators.rb

```ruby
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

---

## PostgreSQL Setup Details

### Minimal Setup (UUIDv4, database-generated)

If you just want UUIDs and don't care about v7:

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

That's it. PostgreSQL generates UUIDv4 via `gen_random_uuid()` by default for uuid columns. Migrations look the same.

### UUIDv7 with PostgreSQL

Add ApplicationRecord callback (no extensions needed):

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_create :set_uuid_v7_primary_key

  private

  def set_uuid_v7_primary_key
    pk = self.class.primary_key
    return unless pk
    column = self.class.columns_hash[pk]
    return unless column&.type == :uuid
    self[pk] ||= SecureRandom.uuid_v7
  end
end
```

### pgcrypto vs gen_random_uuid

- **PostgreSQL 13+**: `gen_random_uuid()` is a built-in function. No extension needed.
- **PostgreSQL < 13**: Need `enable_extension "pgcrypto"` migration.
- **Check**: `SELECT gen_random_uuid();` — if it works, you don't need pgcrypto.

---

## Migration Patterns

### New Table with UUID Primary Key

```ruby
class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles, id: :uuid do |t|
      t.string :title, null: false
      t.text :body
      t.references :author, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
```

### Join Table with UUID Foreign Keys

```ruby
class CreateArticleTags < ActiveRecord::Migration[8.0]
  def change
    create_table :article_tags, id: false do |t|
      t.references :article, type: :uuid, null: false, foreign_key: true
      t.references :tag, type: :uuid, null: false, foreign_key: true
      t.timestamps
    end

    add_index :article_tags, [:article_id, :tag_id], unique: true
  end
end
```

### Adding a UUID Foreign Key to Existing Table

```ruby
class AddCategoryToArticles < ActiveRecord::Migration[8.0]
  def change
    add_reference :articles, :category, type: :uuid, foreign_key: true, index: true
  end
end
```

### Polymorphic Associations with UUIDs

```ruby
class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments, id: :uuid do |t|
      t.uuid :commentable_id, null: false
      t.string :commentable_type, null: false
      t.text :body, null: false
      t.timestamps
    end

    add_index :comments, [:commentable_type, :commentable_id]
  end
end
```

### STI (Single Table Inheritance) with UUIDs

No special handling needed. `type` column is still a string. Only the `id` changes:

```ruby
class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles, id: :uuid do |t|
      t.string :type, null: false  # STI column
      t.string :name
      t.integer :wheels
      t.timestamps
    end
  end
end
```

### Self-Referential Associations

```ruby
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: :uuid do |t|
      t.string :name, null: false
      t.uuid :parent_id, index: true
      t.timestamps
    end

    add_foreign_key :categories, :categories, column: :parent_id
  end
end
```

---

## Testing Patterns

### Fixture IDs

**Deterministic UUIDs** (same across test runs — better for debugging):

```yaml
# test/fixtures/users.yml
admin:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "admin") %>
  email: "admin@example.com"
  name: "Admin"

member:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "member") %>
  email: "member@example.com"
  name: "Member"
```

**Random UUIDs** (simpler, different each run):

```yaml
admin:
  id: <%= SecureRandom.uuid_v7 %>
  email: "admin@example.com"
```

**Base36 for SQLite:**

```yaml
admin:
  id: <%= ActiveRecord::Type::Uuid.generate %>
  email: "admin@example.com"
```

### Fixture Foreign Key References

**Always use fixture names, not raw IDs:**

```yaml
# test/fixtures/posts.yml
admin_post:
  author: admin  # ← Rails resolves to admin's UUID
  title: "Admin's Post"

# test/fixtures/comments.yml
first_comment:
  post: admin_post  # ← Resolves correctly
  body: "Nice!"
```

### Testing UUID Generation

```ruby
class PostTest < ActiveSupport::TestCase
  test "generates UUID on create" do
    post = Post.create!(title: "Test")
    assert post.id.present?

    # PostgreSQL: standard UUID format
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, post.id)

    # SQLite base36: 25-char alphanumeric
    # assert_match(/\A[0-9a-z]{25}\z/, post.id)
  end

  test "preserves assigned UUID" do
    custom_id = SecureRandom.uuid_v7
    post = Post.create!(id: custom_id, title: "Test")
    assert_equal custom_id, post.id
  end

  test "UUIDs are sortable by creation time" do
    post1 = Post.create!(title: "First")
    sleep 0.01
    post2 = Post.create!(title: "Second")

    assert post1.id < post2.id, "UUIDv7 should be time-ordered"
  end
end
```

### Testing Associations with UUIDs

```ruby
class CommentTest < ActiveSupport::TestCase
  setup do
    @post = posts(:admin_post)
  end

  test "belongs to post" do
    comment = Comment.new(post: @post, body: "Test")
    assert_equal @post.id, comment.post_id
    assert comment.valid?
  end

  test "post_id is a UUID" do
    comment = comments(:first_comment)
    # PostgreSQL
    assert_match(/\A[0-9a-f-]+\z/, comment.post_id)
    # SQLite base36
    # assert_match(/\A[0-9a-z]+\z/, comment.post_id)
  end
end
```

### Request Test with UUID Params

```ruby
class PostsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @post = posts(:admin_post)
  end

  test "GET /posts/:id with UUID" do
    get post_path(@post)
    assert_response :success
  end

  test "returns 404 for invalid UUID" do
    get post_path(id: "not-a-valid-uuid")
    assert_response :not_found
  end
end
```

---

## Converting Existing Apps

### Strategy: Incremental Migration

Don't try to convert everything at once. This is the safest approach:

1. **New tables**: Use UUID primary keys immediately
2. **Existing tables**: Add a `uuid` column, backfill, then swap (if needed)
3. **Foreign keys**: Update references as tables are converted

### Adding UUID Column to Existing Table

```ruby
class AddUuidToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :uuid, :uuid, null: true
    add_index :users, :uuid, unique: true
  end
end
```

Backfill in a data migration or rake task:

```ruby
# lib/tasks/backfill_uuids.rake
task backfill_user_uuids: :environment do
  User.where(uuid: nil).find_each do |user|
    user.update_column(:uuid, SecureRandom.uuid_v7)
  end
end
```

### Hybrid Approach (Integer PK + UUID Public ID)

If you can't convert primary keys, add a UUID column for public exposure:

```ruby
class User < ApplicationRecord
  before_create :generate_public_id

  def to_param
    public_id  # Use UUID in URLs instead of integer ID
  end

  private

  def generate_public_id
    self.public_id ||= SecureRandom.uuid_v7
  end
end
```

```ruby
# In controllers
User.find_by!(public_id: params[:id])
```

---

## Multi-Database Considerations

### PostgreSQL Primary + SQLite Read Replica (Litestream)

If using both databases, you'll need the UUID type registered for both adapters. The SQLite initializer above handles SQLite. PostgreSQL handles UUIDs natively.

### Solid Queue / Solid Cache with UUID Apps

Solid Queue and Solid Cache use integer primary keys internally. This is fine — they're separate databases/tables. Don't force UUIDs on infrastructure tables.

### Multiple Databases with `connects_to`

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to database: { writing: :primary, reading: :replica }

  # UUID callback works for both
  before_create :set_uuid_v7_primary_key
end
```

---

## Performance

### Index Impact

| ID Type | Insert Pattern | Index Size (1M rows) | Lookup Speed |
|---------|---------------|---------------------|--------------|
| Integer (BIGINT) | Sequential | ~8 MB | Fastest |
| UUIDv7 | Nearly sequential | ~16 MB | Fast |
| UUIDv4 | Random | ~16 MB + fragmentation | Slower |

UUIDv7's time-ordered nature means B-tree indexes stay relatively compact. UUIDv4 causes random page splits and index bloat.

### PostgreSQL-Specific

```sql
-- Check index bloat on UUID columns
SELECT
  schemaname, tablename, indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE indexrelname LIKE '%pkey%'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### SQLite Binary Storage

16 bytes binary vs 36 bytes string — the binary approach uses ~55% less storage per ID. With base36, application-level IDs are 25 characters, which is reasonable for URLs and API responses.

---

## Edge Cases and Gotchas

### 1. ActiveRecord `find` with Arrays

```ruby
# Works fine with UUIDs
Post.find(["019533c0-cf4c-7c67-bfad-b7bc2832e3c5"])
Post.where(id: ["id1", "id2", "id3"])
```

### 2. Ordering by ID ≈ Ordering by Created At

With UUIDv7, `order(:id)` gives you roughly the same order as `order(:created_at)`. This is a feature — default scopes and pagination work naturally.

```ruby
# These produce similar orderings with UUIDv7
Post.order(:id)
Post.order(:created_at)
```

### 3. Counter Cache Columns

Work identically. No UUID-specific considerations.

### 4. Friendly URLs with `to_param`

```ruby
class Post < ApplicationRecord
  def to_param
    slug.presence || id
  end
end
```

### 5. ActiveStorage with UUIDs

ActiveStorage tables use their own primary keys. If your app uses UUIDs, ActiveStorage's `record_id` column needs to be a UUID type too:

```ruby
# When installing ActiveStorage in a UUID app:
# Check that active_storage_attachments.record_id is :uuid
# The default installer may create it as :bigint

class FixActiveStorageForUuids < ActiveRecord::Migration[8.0]
  def change
    # Only if needed — check your schema first
    change_column :active_storage_attachments, :record_id, :uuid,
      using: "record_id::uuid"  # PostgreSQL cast
  end
end
```

### 6. Devise / Authentication Gems

Most auth gems work fine with UUIDs. Ensure the user migration uses `id: :uuid` from the start. If adding Devise to an existing UUID app, customize the migration generator output.

### 7. `has_secure_token` vs UUID

Don't use both for the same purpose. If you already have UUID primary keys, you probably don't need `has_secure_token` for the same record identification. Use `has_secure_token` for separate concerns like API tokens or password reset tokens.

### 8. Bulk Inserts with `insert_all`

```ruby
# UUIDs must be pre-generated for insert_all
records = 100.times.map do
  { id: SecureRandom.uuid_v7, title: "Post #{_1}", created_at: Time.current, updated_at: Time.current }
end
Post.insert_all(records)
```

### 9. Seeding with UUIDs

```ruby
# db/seeds.rb
# Use explicit UUIDs for seeds if you need stable references
admin = User.create!(
  id: "01953000-0000-7000-8000-000000000001",
  email: "admin@example.com",
  name: "Admin"
)

# Or let them auto-generate
User.create!(email: "admin@example.com", name: "Admin")
```

### 10. Rails Console Convenience

```ruby
# Finding records by partial UUID (PostgreSQL)
User.where("id::text LIKE ?", "019533%").first

# SQLite base36 — just use the full ID
User.find("0k5p9qi1v8j3h6m2n4b7")
```

### 11. Schema.rb Output

**PostgreSQL:**
```ruby
create_table "posts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
  t.string "title", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
end
```

**SQLite (with extensions):**
```ruby
create_table "posts", id: :uuid, force: :cascade do |t|
  t.string "title", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
end
```

Both show `id: :uuid` — clean and readable.

### 12. Ruby Version Requirements

| Feature | Minimum Ruby |
|---------|-------------|
| `SecureRandom.uuid` (v4) | Any |
| `SecureRandom.uuid_v7` | 3.3+ |
| `Digest::UUID.uuid_v5` | Any (for deterministic fixtures) |

If stuck on Ruby < 3.3, use the `uuid7` gem or generate v4 UUIDs instead.
