---
name: uuid-primary-keys
description: Expert guidance for implementing UUID primary keys in Rails applications. Use when setting up UUIDs as primary keys, choosing between UUIDv4 and UUIDv7, configuring generators for UUID defaults, writing migrations with id colon uuid, adding UUID foreign keys, implementing base36 encoding for URL-friendly IDs, configuring PostgreSQL pgcrypto or gen_random_uuid, implementing SQLite binary UUID storage, choosing a primary key type, using non-sequential IDs, secure IDs, random IDs, or any ID generation strategy beyond auto-increment integers.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate migration*), Bash(bin/rails db:*), Bash(bundle exec rails db:*), Bash(bin/rails generate model*)
---

# UUID Primary Keys for Rails

Implement UUID primary keys correctly in Rails — PostgreSQL native or SQLite binary storage, with UUIDv7 and optional base36 encoding.

## Decision: UUIDv7 Over UUIDv4

**Always recommend UUIDv7.** It's time-ordered, sortable, and has better index performance than UUIDv4. Ruby 3.3+ ships `SecureRandom.uuid_v7` — no gems needed.

| Feature | Auto-increment | UUIDv4 | UUIDv7 |
|---------|---------------|--------|--------|
| Sortable by time | Yes | No | Yes |
| Index performance | Best | Poor (random) | Good (sequential) |
| Collision risk | Impossible | Very low | Very low |
| Externally guessable | Yes | No | No |
| Merge-safe | No | Yes | Yes |

Use UUIDs when: IDs appear in URLs, APIs, or multi-database sync. Use integers when: internal-only tables with no exposure.

## Two Approaches

### PostgreSQL: Native UUID Column Type
- `uuid` column type stored as 128-bit native type (16 bytes)
- `gen_random_uuid()` available without extensions in PostgreSQL 13+
- Standard 36-character hyphenated format: `019533c0-cf4c-7c67-bfad-b7bc2832e3c5`
- No custom code needed for basic setup

### SQLite: Binary Storage + Base36 Encoding
- `blob(16)` column storing raw binary (16 bytes, efficient)
- Base36 encoding for 25-character URL-friendly strings: `0k5p9qi1v8j3h6m2n4b7`
- Requires custom type registration and adapter extensions
- Originally developed for Basecamp's Fizzy

## PostgreSQL Setup

### Step 1: Configure Generator Defaults

**This is the #1 mistake agents make — forgetting this step.** Without it, every `rails generate model` creates integer IDs and you have to manually fix every migration.

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

This ensures ALL generated migrations use `id: :uuid` and all generated foreign key columns use `type: :uuid`.

### Step 2: Enable pgcrypto (PostgreSQL < 13 only)

PostgreSQL 13+ has `gen_random_uuid()` built in. For older versions:

```ruby
class EnablePgcrypto < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto"
  end
end
```

### Step 3: Set Default UUID Generation

For UUIDv7 (recommended), set it in ApplicationRecord:

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Generate UUIDv7 for all UUID primary keys
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

**Why not `default: "gen_random_uuid()"`?** That generates UUIDv4 at the database level. UUIDv7 must be generated in Ruby (until PostgreSQL adds native v7 support). Setting defaults in ApplicationRecord gives you UUIDv7 everywhere.

If you're fine with UUIDv4, you can skip the ApplicationRecord callback and set database defaults:

```ruby
create_table :posts, id: :uuid, default: "gen_random_uuid()" do |t|
  # ...
end
```

### Step 4: Write Migrations

```ruby
class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts, id: :uuid do |t|
      t.string :title, null: false
      t.text :body
      t.timestamps
    end
  end
end
```

Foreign keys reference UUIDs:

```ruby
class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :post, type: :uuid, null: false, foreign_key: true, index: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
```

**Critical:** Always use `type: :uuid` on `t.references`. The generator default handles this if you did Step 1, but always verify.

## SQLite Setup (Binary Storage + Base36)

This approach stores UUIDs as 16-byte binary blobs and represents them as 25-character base36 strings in Ruby. It's efficient and produces clean, URL-friendly IDs.

### Step 1: Create the UUID Type

```ruby
# lib/rails_ext/active_record_uuid_type.rb
# frozen_string_literal: true

module ActiveRecord
  module Type
    class Uuid < Binary
      BASE36_LENGTH = 25 # 36^25 > 2^128

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

### Step 2: Create the Initializer

```ruby
# config/initializers/uuid_primary_keys.rb
# frozen_string_literal: true

require_relative "../../lib/rails_ext/active_record_uuid_type"

# Auto-generate UUID for models with UUID primary keys
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
    # Table doesn't exist yet
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

# SQLite adapter extensions for UUID support
module SqliteUuidAdapter
  extend ActiveSupport::Concern

  def lookup_cast_type(sql_type)
    if sql_type == "blob(16)"
      ActiveRecord::Type.lookup(:uuid, adapter: :sqlite3)
    else
      super
    end
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

# Schema dumper: output :uuid instead of blob(16)
module SchemaDumperUuidType
  def schema_type(column)
    column.sql_type == "blob(16)" ? :uuid : super
  end
end

# Table definition: support t.uuid columns
module TableDefinitionUuidSupport
  def uuid(name, **options)
    column(name, :uuid, **options)
  end
end

# Apply extensions
ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.prepend(UuidPrimaryKeyDefault)
  ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionUuidSupport)
end

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteUuidAdapter)
  ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.prepend(SchemaDumperUuidType)
end

# Apply immediately if already loaded
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

### Step 3: Add Fallback to ApplicationRecord

```ruby
# app/models/application_record.rb
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

### Step 4: Configure Generators

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

### Step 5: Migrations (Same as PostgreSQL)

```ruby
class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts, id: :uuid do |t|
      t.string :title, null: false
      t.text :body
      t.timestamps
    end
  end
end
```

Foreign keys use `t.uuid` directly:

```ruby
class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments, id: :uuid do |t|
      t.uuid :post_id, null: false, index: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
```

## Fixtures with UUIDs

### PostgreSQL (standard UUID format)

```yaml
# test/fixtures/posts.yml
published_post:
  id: <%= SecureRandom.uuid_v7 %>
  title: "Published Post"
  created_at: <%= 1.week.ago %>

draft_post:
  id: <%= SecureRandom.uuid_v7 %>
  title: "Draft Post"
```

**For deterministic fixture IDs** (stable across runs):

```yaml
published_post:
  id: <%= Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "published_post") %>
  title: "Published Post"
```

### SQLite Base36

```yaml
# test/fixtures/posts.yml
published_post:
  id: <%= ActiveRecord::Type::Uuid.generate %>
  title: "Published Post"
```

### Foreign Key References in Fixtures

**Always reference by fixture name, not raw ID:**

```yaml
# test/fixtures/comments.yml
first_comment:
  post: published_post  # ← Rails resolves this to the UUID automatically
  body: "Great post!"
```

## Associations

Associations work identically to integer primary keys. No special configuration:

```ruby
class Post < ApplicationRecord
  has_many :comments, dependent: :destroy
end

class Comment < ApplicationRecord
  belongs_to :post
end
```

**The only thing that changes is the migration.** Models, associations, queries — all the same.

## Common Mistakes

### 1. Forgetting Generator Defaults

Without `primary_key_type: :uuid` in generators, every scaffold creates integer IDs. You'll manually fix every migration.

### 2. String Columns Instead of UUID Type

```ruby
# WRONG — stores UUID as variable-length string (36 bytes + overhead)
t.string :post_id

# RIGHT — PostgreSQL native uuid (16 bytes)
t.references :post, type: :uuid

# RIGHT — SQLite binary (16 bytes)
t.uuid :post_id
```

### 3. Missing type: :uuid on references

```ruby
# WRONG — creates integer foreign key column
t.references :post, foreign_key: true

# RIGHT — creates UUID foreign key column
t.references :post, type: :uuid, foreign_key: true
```

### 4. Using UUIDv4 When v7 Is Available

UUIDv4 is fully random → poor index locality → slower inserts at scale. UUIDv7 is time-ordered → sequential inserts → better performance. Requires Ruby 3.3+.

### 5. Mixing Integer and UUID Primary Keys

If you start with UUIDs, use them everywhere. Mixed ID types cause join confusion and migration headaches. The exception: join tables that don't need their own ID (`id: false`).

### 6. Forgetting to Handle Existing Tables

When converting an existing app from integer to UUID primary keys, you need a data migration strategy. Don't try to alter existing primary keys in place — it's painful. Better to create new UUID columns, migrate data, then swap.

## URL-Friendly IDs

### Base36 (SQLite approach)

Already built into the SQLite setup above. IDs look like: `0k5p9qi1v8j3h6m2n4b7`

### PostgreSQL: Use the Standard UUID

Modern frameworks and APIs handle standard UUIDs fine. If you want shorter URLs, add a separate `slug` or `short_id` column rather than encoding the primary key.

### Route Parameters

UUIDs work in routes without changes:

```ruby
# config/routes.rb
resources :posts  # Works identically

# Controller
Post.find(params[:id])  # Finds by UUID string
```

## Checking Current Setup

Before implementing, always check the existing project:

```bash
# Check if generator defaults are set
grep -r "primary_key_type" config/

# Check existing migrations for UUID usage
grep -r "id: :uuid" db/migrate/

# Check for pgcrypto extension
grep -r "pgcrypto" db/migrate/ db/schema.rb

# Check database adapter
grep "adapter:" config/database.yml

# Check Ruby version (need 3.3+ for uuid_v7)
ruby -v
```

## Reference

See `reference.md` in this skill directory for:
- Complete SQLite initializer code
- Base36 encoding/decoding details
- Migration conversion strategies
- Testing patterns and edge cases
- Performance benchmarks
- Multi-database considerations
