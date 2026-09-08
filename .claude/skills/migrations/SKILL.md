---
name: migrations
description: Expert guidance for writing safe, reversible Active Record migrations in Rails applications. Use when creating a migration, adding a column, removing a column, changing schema, modifying a table, creating a table, adding an index, adding a foreign key, renaming a column, changing column type, database migration, schema change, rolling back, migration error, data migration, multi-database migration, or any database structure change.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate migration*), Bash(bin/rails db:*), Bash(bundle exec rails db:*), Bash(bin/rails generate model*)
---

# Rails Migrations Expert

Write safe, reversible, forward-only migrations for Rails 8.1 applications.

## Golden Rules

These are non-negotiable. Violating any of them causes real production pain.

### 1. NEVER Edit Old Migrations

Once a migration has been committed (especially if run in production), it is **frozen forever**. Don't touch it. Write a new migration instead.

```ruby
# BAD — editing an existing, committed migration
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name  # ← sneaking this in after the fact
    end
  end
end

# GOOD — new migration to add the column
class AddNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
  end
end
```

**Why:** Other developers and environments have already run the old version. Editing it breaks `db:migrate` for everyone and causes schema drift.

**Exception:** A migration you just generated that hasn't been committed or run anywhere else — edit freely.

### 2. NEVER Modify the Database Directly

All schema changes go through migrations. No exceptions.

```bash
# BAD
sqlite3 db/development.sqlite3 "ALTER TABLE users ADD COLUMN name TEXT"

# GOOD
bin/rails generate migration AddNameToUsers name:string
bin/rails db:migrate
```

**Why:** Direct changes aren't tracked, `schema.rb` falls out of sync, and other environments won't have the changes.

### 3. Always Move Forward

Migrations are append-only. To fix mistakes, write a **new** migration.

```ruby
# Wrong column type? New migration.
class ChangePostsBodyToText < ActiveRecord::Migration[8.1]
  def up
    change_column :posts, :body, :text
  end

  def down
    change_column :posts, :body, :string
  end
end

# Need to remove a column? New migration.
class RemoveObsoleteColumnFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :obsolete_field, :string
  end
end
```

## Instructions

### Step 1: Understand What You're Changing

Before writing a migration, check the current schema:

```bash
# Check current schema
cat db/schema.rb | grep -A 20 "create_table \"users\""

# Check migration status
bin/rails db:migrate:status

# Check existing migrations
ls -la db/migrate/
```

Know the current state before changing it.

### Step 2: Generate the Migration

Use Rails generators — they create the file with the right timestamp and class structure. Name your migrations descriptively using Rails conventions:

```bash
# Creating a table (CreateXxx)
bin/rails generate migration CreatePosts title:string body:text published_at:datetime

# Adding columns (AddXxxToYyy)
bin/rails generate migration AddCategoryToPosts category:string

# Removing columns (RemoveXxxFromYyy)
bin/rails generate migration RemoveLegacyFieldFromUsers legacy_field:string

# Adding a reference/foreign key
bin/rails generate migration AddUserRefToPosts user:references

# Adding an index
bin/rails generate migration AddPartNumberToProducts part_number:string:index

# General changes (descriptive name)
bin/rails generate migration ChangePostsBodyToText
```

**Generator shortcuts:**
- `name:string` — default type is `string` if omitted, so `name` alone works
- `user:references` — creates `user_id` column + index + foreign key
- `price:decimal{5,2}` — precision and scale modifiers
- `email:string!` — adds `null: false` constraint

### Step 3: Write the Migration Body

Use the `change` method for reversible operations (Rails handles rollback automatically):

```ruby
class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :body
      t.references :author, null: false, foreign_key: true
      t.datetime :published_at
      t.timestamps
    end

    add_index :posts, :published_at
    add_index :posts, :title
  end
end
```

For **irreversible** operations, use `up`/`down`:

```ruby
class ChangePostsExcerptToText < ActiveRecord::Migration[8.1]
  def up
    change_column :posts, :excerpt, :text
  end

  def down
    change_column :posts, :excerpt, :string, limit: 500
  end
end
```

For **mixed** operations (some reversible, some not), use `reversible` inside `change`:

```ruby
class AddStatusToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :status, :string, default: "draft"

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

### Step 4: Run and Verify

```bash
# Run pending migrations
bin/rails db:migrate

# Check it worked
bin/rails db:migrate:status

# If something's wrong with the LAST migration (before committing)
bin/rails db:rollback
# Fix the migration, then re-run
bin/rails db:migrate
```

### Step 5: Commit schema.rb

Always commit `db/schema.rb` (or `db/structure.sql`) alongside your migration. This file is the authoritative schema snapshot.

## Critical Gotchas

### Always Index Foreign Keys

Every foreign key column needs an index. No exceptions.

```ruby
# BAD — foreign key without index
t.bigint :author_id, null: false

# GOOD — use references (index included automatically)
t.references :author, null: false, foreign_key: true

# GOOD — manual column with explicit index
t.bigint :author_id, null: false, index: true
```

### NOT NULL on Existing Tables Requires a Default

Adding a `NOT NULL` column to a table that already has rows will fail without a default value.

```ruby
# BAD — fails if table has data
add_column :posts, :status, :string, null: false

# GOOD — provide a default
add_column :posts, :status, :string, null: false, default: "draft"
```

### Never Reference Application Models in Migrations

Models change over time. Migrations are frozen in time. They will break.

```ruby
# BAD — model may not exist or may have different validations later
class BackfillPostSlugs < ActiveRecord::Migration[8.1]
  def up
    Post.find_each { |p| p.update!(slug: p.title.parameterize) }
  end
end

# GOOD — use raw SQL
class BackfillPostSlugs < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE posts SET slug = lower(replace(title, ' ', '-')) WHERE slug IS NULL
    SQL
  end
end

# ACCEPTABLE — inline class that won't change
class BackfillPostSlugs < ActiveRecord::Migration[8.1]
  class Post < ApplicationRecord; end

  def up
    Post.where(slug: nil).find_each do |post|
      post.update_column(:slug, post.title.parameterize)
    end
  end
end
```

### Don't Use Dynamic Ruby Values as Defaults

```ruby
# BAD — evaluates once at migration time, frozen forever
add_column :posts, :migrated_at, :datetime, default: Time.current

# GOOD — SQL function evaluates at row insertion time
add_column :posts, :migrated_at, :datetime, default: -> { "CURRENT_TIMESTAMP" }
```

### Always Include Column Type in remove_column

Without the type, Rails can't reverse the migration.

```ruby
# BAD — irreversible
remove_column :users, :legacy_field

# GOOD — reversible
remove_column :users, :legacy_field, :string
```

### change_column Is NOT Reversible

Rails can't guess the old type. Always use `up`/`down`:

```ruby
# BAD — will fail on rollback
def change
  change_column :posts, :body, :text
end

# GOOD
def up
  change_column :posts, :body, :text
end

def down
  change_column :posts, :body, :string
end
```

## Reversible Operations Quick Reference

**Auto-reversible in `change`:**
- `create_table` / `drop_table` (drop needs block + options)
- `add_column` / `remove_column` (remove needs type)
- `add_index` / `remove_index` (remove needs column + options)
- `add_reference` / `remove_reference`
- `add_foreign_key` / `remove_foreign_key`
- `add_timestamps` / `remove_timestamps`
- `rename_column`, `rename_table`, `rename_index`
- `change_column_default` (needs `from:` and `to:`)
- `change_column_null`
- `add_check_constraint` / `remove_check_constraint`

**Require `up`/`down` or `reversible`:**
- `change_column` (type changes)
- `execute` (raw SQL)
- Any data manipulation

## Data Migrations

### Small, Schema-Related Updates

Include them in the migration with `reversible`:

```ruby
class AddStatusToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :status, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute "UPDATE posts SET status = 1 WHERE published_at IS NOT NULL"
      end
    end
  end
end
```

### Large Data Migrations

Don't put them in schema migrations. Use a rake task or the `maintenance_tasks` gem:

```ruby
# lib/tasks/data_migrations.rake
namespace :data do
  desc "Backfill post statuses"
  task backfill_post_statuses: :environment do
    Post.where(status: nil).find_each(batch_size: 1000) do |post|
      post.update_column(:status, post.published_at? ? 1 : 0)
    end
  end
end
```

**Why separate?** Data migrations can be slow, may need to run at specific times, and have different rollback characteristics than schema changes.

## Multi-Database Migrations

When the app uses multiple databases:

```bash
# Default database migrations go in db/migrate/
# Other databases use their own directories (configured in database.yml)

# Run specific database migrations
bin/rails db:migrate              # primary database
bin/rails db:migrate:animals      # "animals" database (example)

# Generate for a specific database
bin/rails generate migration CreateDogs name:string --database animals
```

Migration files for secondary databases live in their configured `migrations_paths` directory (e.g., `db/animals_migrate/`).

## Commands Reference

```bash
# Generate
bin/rails generate migration AddNameToUsers name:string
bin/rails generate model Post title:string body:text

# Run
bin/rails db:migrate                      # Run all pending
bin/rails db:migrate VERSION=20240428...  # Migrate to specific version

# Rollback
bin/rails db:rollback                     # Undo last migration
bin/rails db:rollback STEP=3              # Undo last 3
bin/rails db:migrate:redo                 # Rollback + re-migrate last

# Status
bin/rails db:migrate:status               # Show up/down status of all

# Schema
bin/rails db:schema:dump                  # Regenerate schema.rb
bin/rails db:schema:load                  # Load schema (destructive!)

# Setup / Reset
bin/rails db:setup                        # Create + load schema + seed
bin/rails db:prepare                      # Idempotent setup
bin/rails db:reset                        # Drop + setup
bin/rails db:migrate:reset                # Drop + migrate from scratch

# Specific migration
bin/rails db:migrate:up VERSION=20240428...
bin/rails db:migrate:down VERSION=20240428...

# Environment
bin/rails db:migrate RAILS_ENV=test
```

## When to Use This Skill

- Creating new tables or modifying existing ones
- Adding, removing, or renaming columns
- Adding indexes or foreign keys
- Changing column types or constraints
- Writing data backfill migrations
- Debugging migration errors or rollback issues
- Setting up multi-database migrations
- Understanding schema.rb vs structure.sql

For detailed column types, index patterns, UUID setup, check constraints, and advanced examples, see `reference.md` in this skill directory.
