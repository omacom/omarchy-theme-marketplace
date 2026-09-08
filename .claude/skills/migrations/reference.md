# Rails Migrations Reference

Detailed patterns, column types, edge cases, and advanced examples for Active Record migrations in Rails 8.1.

## Table of Contents
- [Column Types Reference](#column-types-reference)
- [Table Creation Patterns](#table-creation-patterns)
- [Index Patterns](#index-patterns)
- [Foreign Key Patterns](#foreign-key-patterns)
- [Column Change Patterns](#column-change-patterns)
- [Check Constraints (Rails 6.1+)](#check-constraints-rails-61)
- [Enum Columns (PostgreSQL)](#enum-columns-postgresql)
- [Polymorphic Associations](#polymorphic-associations)
- [change_table (Batch Changes)](#change_table-batch-changes)
- [Reversible Pattern Cookbook](#reversible-pattern-cookbook)
- [Data Migration Patterns](#data-migration-patterns)
- [Multi-Database Patterns](#multi-database-patterns)
- [DDL Transactions](#ddl-transactions)
- [Schema Management](#schema-management)
- [Troubleshooting](#troubleshooting)
- [Anti-Patterns](#anti-patterns)

## Column Types Reference

### Standard Types

| Type | Ruby | Database (PostgreSQL) | Notes |
|------|------|-----------------------|-------|
| `string` | `String` | `varchar(255)` | Default limit 255. Use for short text. |
| `text` | `String` | `text` | Unlimited length. Use for long-form content. |
| `integer` | `Integer` | `integer` (4 bytes) | -2B to 2B. Use `limit:` for smaller/larger. |
| `bigint` | `Integer` | `bigint` (8 bytes) | Default for `id` columns. |
| `float` | `Float` | `float` | Imprecise. Don't use for money. |
| `decimal` | `BigDecimal` | `decimal` | Precise. Use `precision:` and `scale:`. |
| `boolean` | `true/false` | `boolean` | Always set a default. |
| `date` | `Date` | `date` | Date only, no time. |
| `time` | `Time` | `time` | Time only, no date. |
| `datetime` | `DateTime` | `timestamp` | Date + time. Preferred over `timestamp`. |
| `binary` | `String` | `bytea` | Raw binary data. |
| `json` | `Hash/Array` | `json` | Stored as text, parsed on read. |
| `jsonb` | `Hash/Array` | `jsonb` (PG only) | Binary JSON. Indexable. Prefer over `json`. |
| `uuid` | `String` | `uuid` | 128-bit identifier. Needs PG `pgcrypto`. |
| `inet` | `IPAddr` | `inet` (PG only) | IP addresses. |
| `cidr` | `IPAddr` | `cidr` (PG only) | Network addresses. |
| `macaddr` | `String` | `macaddr` (PG only) | MAC addresses. |
| `hstore` | `Hash` | `hstore` (PG only) | Key-value pairs. Prefer `jsonb`. |
| `enum` | `String` | `enum` (PG only) | Database-level enum type. |

### Integer Limits

```ruby
t.integer :tiny,   limit: 1  # tinyint   (-128 to 127)
t.integer :small,  limit: 2  # smallint  (-32K to 32K)
t.integer :medium, limit: 3  # mediumint (-8M to 8M, MySQL only)
t.integer :normal, limit: 4  # integer   (-2B to 2B) — default
t.integer :big,    limit: 8  # bigint    (-9.2 quintillion to 9.2 quintillion)
```

### Decimal Precision

```ruby
# Money — 8 digits total, 2 after decimal: up to 999,999.99
t.decimal :price, precision: 8, scale: 2

# Coordinates — high precision
t.decimal :latitude, precision: 10, scale: 6
t.decimal :longitude, precision: 10, scale: 6

# Percentages — e.g., 99.99
t.decimal :rate, precision: 5, scale: 2
```

### Column Modifiers

```ruby
t.string :name,
  null: false,                          # NOT NULL constraint
  default: "untitled",                  # Default value
  limit: 100,                           # Max characters (string) or bytes (binary)
  index: true,                          # Create an index
  index: { unique: true },              # Unique index
  comment: "The user's display name",   # Database-level comment
  collation: "utf8mb4_general_ci"       # Collation (MySQL)
```

## Table Creation Patterns

### Basic Table

```ruby
class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :body
      t.string :slug, null: false
      t.integer :status, default: 0, null: false
      t.datetime :published_at
      t.timestamps
    end

    add_index :posts, :slug, unique: true
    add_index :posts, :status
    add_index :posts, :published_at
  end
end
```

### Table with UUID Primary Key

```ruby
class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts, id: :uuid do |t|
      t.string :title, null: false
      t.text :body
      t.references :author, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
```

**Project-wide UUID setup** in `config/application.rb`:

```ruby
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

When using UUIDs, **always specify `type: :uuid`** on references:

```ruby
# Without project-wide config, you must be explicit
t.references :author, type: :uuid, null: false, foreign_key: { to_table: :users }
```

### Table Without Primary Key

```ruby
create_table :settings, id: false do |t|
  t.string :key, null: false
  t.string :value
  t.timestamps
end

add_index :settings, :key, unique: true
```

### Composite Primary Key

```ruby
create_table :travel_routes, primary_key: [:origin_id, :destination_id] do |t|
  t.bigint :origin_id
  t.bigint :destination_id
  t.integer :distance
end
```

### Join Table (HABTM)

```ruby
class CreateJoinTableUsersRoles < ActiveRecord::Migration[8.1]
  def change
    create_join_table :users, :roles do |t|
      t.index [:user_id, :role_id], unique: true
      t.index :role_id
    end
  end
end
```

## Index Patterns

### Basic Indexes

```ruby
# Single column
add_index :users, :email

# Unique
add_index :users, :email, unique: true

# Composite (order matters for query performance)
add_index :posts, [:author_id, :published_at]

# Named index (useful when auto-generated name is too long)
add_index :posts, [:workspace_id, :author_id, :created_at],
  name: "idx_posts_workspace_author_created"
```

### Partial Indexes (WHERE clause)

Only index rows matching a condition. Smaller, faster.

```ruby
# Only index published posts
add_index :posts, :published_at, where: "published_at IS NOT NULL"

# Only index active users
add_index :users, :email, unique: true, where: "active = true"

# Only index non-deleted records (soft delete)
add_index :posts, :slug, unique: true, where: "deleted_at IS NULL"
```

### Expression Indexes (PostgreSQL)

```ruby
# Case-insensitive email lookup
add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"

# GIN index for JSONB queries
add_index :posts, :metadata, using: :gin

# GiST index for full-text search
add_index :posts, "to_tsvector('english', title || ' ' || body)", using: :gin,
  name: "index_posts_on_fulltext"
```

### Concurrent Index Creation (PostgreSQL)

For adding indexes to large tables without locking:

```ruby
class AddIndexToUsersEmail < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :email, unique: true, algorithm: :concurrently
  end
end
```

**Important:** `algorithm: :concurrently` requires `disable_ddl_transaction!` because concurrent index creation can't run inside a transaction.

## Foreign Key Patterns

### Basic Foreign Key

```ruby
# Using references (preferred — creates column + index + FK)
add_reference :posts, :user, null: false, foreign_key: true

# Adding FK to existing column
add_foreign_key :posts, :users

# Custom column name
add_foreign_key :posts, :users, column: :author_id

# Custom referenced column
add_foreign_key :articles, :authors, column: :reviewer, primary_key: :email
```

### ON DELETE Behavior

```ruby
# Cascade — delete posts when user is deleted
add_foreign_key :posts, :users, on_delete: :cascade

# Nullify — set author_id to NULL when user is deleted
add_foreign_key :posts, :users, column: :author_id, on_delete: :nullify

# Restrict — prevent deleting user if posts exist (default)
add_foreign_key :posts, :users, on_delete: :restrict
```

### Self-Referential Foreign Key

```ruby
class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.references :post, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :comments }
      t.timestamps
    end
  end
end
```

### Removing Foreign Keys

```ruby
# By referenced table
remove_foreign_key :posts, :users

# By column
remove_foreign_key :posts, column: :author_id

# By name
remove_foreign_key :posts, name: "fk_posts_author"
```

## Column Change Patterns

### Adding Columns

```ruby
# Basic
add_column :users, :name, :string

# With constraints
add_column :users, :email, :string, null: false, default: ""

# With index
add_column :posts, :category, :string
add_index :posts, :category
```

### Removing Columns

```ruby
# Always include the type for reversibility
remove_column :users, :legacy_field, :string

# Multiple columns at once
remove_columns :users, :legacy_field, :old_status, type: :string
```

### Renaming Columns

```ruby
rename_column :users, :name, :full_name
```

### Changing Column Type

```ruby
# IRREVERSIBLE — must use up/down
def up
  change_column :posts, :view_count, :bigint
end

def down
  change_column :posts, :view_count, :integer
end
```

### Changing Nullability

```ruby
# Make NOT NULL (ensure no NULLs exist first!)
change_column_null :users, :email, false

# Allow NULL
change_column_null :users, :bio, true

# Set NOT NULL with a default for existing NULL values
change_column_null :users, :name, false, "Unknown"
```

### Changing Defaults

```ruby
# Reversible (preferred) — specify from/to
change_column_default :posts, :status, from: nil, to: "draft"

# Irreversible — just set the new default
change_column_default :posts, :status, "draft"

# Remove default
change_column_default :posts, :status, from: "draft", to: nil
```

## Check Constraints (Rails 6.1+)

```ruby
# Add a check constraint
add_check_constraint :orders, "total >= 0", name: "orders_total_non_negative"

# In create_table
create_table :products do |t|
  t.decimal :price, precision: 8, scale: 2
  t.integer :quantity
  t.timestamps

  t.check_constraint "price >= 0", name: "products_price_non_negative"
  t.check_constraint "quantity >= 0", name: "products_quantity_non_negative"
end

# Remove (must supply original expression for reversibility)
remove_check_constraint :orders, "total >= 0", name: "orders_total_non_negative"
```

## Enum Columns (PostgreSQL)

```ruby
class AddStatusToOrders < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'delivered');
    SQL
    add_column :orders, :status, :order_status, default: "pending", null: false
  end

  def down
    remove_column :orders, :status
    execute "DROP TYPE order_status;"
  end
end
```

**Adding a value to an existing enum:**

```ruby
class AddCancelledToOrderStatus < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!  # Required — ALTER TYPE can't run in a transaction

  def up
    execute "ALTER TYPE order_status ADD VALUE 'cancelled'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Cannot remove enum value. Create a new enum type if needed."
  end
end
```

## Polymorphic Associations

```ruby
class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.references :commentable, polymorphic: true, null: false
      t.timestamps
    end
  end
end
```

This creates `commentable_id` (bigint), `commentable_type` (string), and a composite index on both.

## change_table (Batch Changes)

Modify an existing table with multiple operations:

```ruby
change_table :products do |t|
  t.remove :description, :name
  t.string :part_number
  t.index :part_number
  t.rename :upccode, :upc_code
end
```

## Reversible Pattern Cookbook

### Execute Raw SQL Reversibly

```ruby
def change
  reversible do |dir|
    dir.up do
      execute <<~SQL
        CREATE VIEW active_users AS
        SELECT * FROM users WHERE active = true;
      SQL
    end
    dir.down do
      execute "DROP VIEW active_users;"
    end
  end
end
```

### Revert a Previous Migration

```ruby
require_relative "20240101000000_create_legacy_table"

class RemoveLegacyTable < ActiveRecord::Migration[8.1]
  def change
    revert CreateLegacyTable
  end
end
```

### Partially Revert

```ruby
class FixPreviousMigration < ActiveRecord::Migration[8.1]
  def change
    revert do
      # This block is "undone" — reversed
      add_column :users, :wrong_column, :string
      add_index :users, :wrong_column
    end
  end
end
```

## Data Migration Patterns

### Inline (Small Updates)

```ruby
class AddStatusToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :status, :string, default: "draft", null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE posts SET status = 'published' WHERE published_at IS NOT NULL
        SQL
      end
    end
  end
end
```

### Inline Class Pattern (When SQL Is Awkward)

```ruby
class BackfillUserSlugs < ActiveRecord::Migration[8.1]
  class User < ActiveRecord::Base; end  # Frozen snapshot — won't change

  def up
    User.where(slug: nil).find_each do |user|
      user.update_column(:slug, user.name.parameterize)
    end
  end

  def down
    User.update_all(slug: nil)
  end
end
```

**Key:** Use `update_column` (not `update!`) to skip validations and callbacks that may not exist yet or may have changed.

### Large Data Migration (Separate Task)

For migrations affecting millions of rows, use `maintenance_tasks` or a rake task:

```ruby
# lib/tasks/data/backfill_post_statuses.rake
namespace :data do
  desc "Backfill post statuses"
  task backfill_post_statuses: :environment do
    Post.where(status: nil).in_batches(of: 1000) do |batch|
      batch.update_all(status: "draft")
    end
  end
end
```

Run separately from deploys: `bin/rails data:backfill_post_statuses`

## Multi-Database Patterns

### Configuration

```yaml
# config/database.yml
production:
  primary:
    <<: *default
    database: myapp_primary
    migrations_paths: db/migrate
  animals:
    <<: *default
    database: myapp_animals
    migrations_paths: db/animals_migrate
```

### Generating

```bash
bin/rails generate migration CreateDogs name:string --database animals
# Creates file in db/animals_migrate/
```

### Running

```bash
bin/rails db:migrate                 # All databases
bin/rails db:migrate:primary         # Primary only
bin/rails db:migrate:animals         # Animals only
bin/rails db:rollback:animals        # Rollback animals
```

### Cross-Database Foreign Keys

You **cannot** create foreign keys across databases. Use application-level validation instead.

## DDL Transactions

### Default Behavior

Each migration runs inside a database transaction (on databases that support DDL transactions like PostgreSQL). If any statement fails, the whole migration is rolled back.

### Disabling Transactions

Some operations can't run inside a transaction:

```ruby
class AddIndexConcurrently < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

**Operations that need `disable_ddl_transaction!`:**
- `algorithm: :concurrently` (concurrent index creation)
- `ALTER TYPE ... ADD VALUE` (PostgreSQL enum changes)
- Some extension operations

## Schema Management

### schema.rb vs structure.sql

| Feature | `schema.rb` (default) | `structure.sql` |
|---------|----------------------|-----------------|
| Format | Ruby DSL | Raw SQL |
| Database features | Common subset only | Everything |
| Triggers, views, functions | ❌ Not supported | ✅ Full support |
| Custom types, enums | ❌ Not supported | ✅ Full support |
| Readability | High | Lower |
| Merge conflicts | Easier to resolve | Harder |

Switch with:
```ruby
# config/application.rb
config.active_record.schema_format = :sql
```

### Regenerating Schema

```bash
# From migrations
bin/rails db:schema:dump

# From database structure (if schema is out of sync)
bin/rails db:schema:dump
```

### Loading Schema (Fresh DB)

```bash
# Load schema.rb
bin/rails db:schema:load

# This is what db:setup and db:prepare use internally
# Much faster than running all migrations from scratch
```

## Troubleshooting

### "Migrations are pending"

```bash
bin/rails db:migrate
# Or check what's pending:
bin/rails db:migrate:status
```

### Migration Failed Halfway

On PostgreSQL (with DDL transactions), the whole migration rolls back. On MySQL, you may have a partial migration — fix manually and re-run.

### Schema Conflicts After Merge

```bash
# After resolving git conflicts in schema.rb:
bin/rails db:migrate
# This regenerates schema.rb from the actual database state
```

### "Table already exists" / "Column already exists"

The migration was partially applied (usually MySQL without DDL transactions). Options:
1. Manually drop the table/column, then re-run
2. Mark the migration as run: `bin/rails db:migrate:up VERSION=...`
3. Add `if_not_exists: true` to the migration (Rails 6.1+)

```ruby
create_table :posts, if_not_exists: true do |t|
  # ...
end

add_column :posts, :status, :string, if_not_exists: true  # Rails 7.1+
```

### Rolling Back Multiple Steps

```bash
bin/rails db:rollback STEP=3    # Undo last 3 migrations
bin/rails db:migrate:redo STEP=3  # Rollback 3, then re-migrate
```

### Seeing What SQL a Migration Generates

```bash
bin/rails db:migrate:status      # See pending migrations
bin/rails db:migrate --verbose   # See SQL output during migration
```

## Anti-Patterns

1. **Editing committed migrations** — Write a new one instead
2. **Referencing models directly** — Use raw SQL or inline classes
3. **Missing indexes on foreign keys** — Every FK needs an index
4. **NOT NULL without default on populated tables** — Provide a default value
5. **Using `Time.current` as a default** — Use `-> { "CURRENT_TIMESTAMP" }` instead
6. **Forgetting column type in `remove_column`** — Makes rollback impossible
7. **Using `change` for irreversible operations** — Use `up`/`down`
8. **Huge data migrations in schema migrations** — Use rake tasks or maintenance_tasks
9. **Modifying the database directly** — Always go through migrations
10. **Depending on column order** — SQL doesn't guarantee column order
