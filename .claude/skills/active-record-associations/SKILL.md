---
name: active-record-associations
description: Expert guidance for defining and using Active Record associations in Rails. Use when creating associations, defining model relationships, troubleshooting foreign keys, fixing N+1 queries, setting up belongs_to, has_many, has_one, has_many :through, polymorphic associations, self-referential joins, join tables, counter caches, dependent options, inverse_of, eager loading, or any question about how models relate to each other.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate*), Bash(bin/rails db:migrate*), Bash(bin/rails console*)
---

# Active Record Associations Expert

Define correct, performant, and maintainable associations between Rails models.

## Philosophy

**Core Principles:**
1. **The FK lives on the `belongs_to` side** — always. If you're confused about where it goes, ask "which table has the `_id` column?" That model gets `belongs_to`.
2. **Always set `dependent:`** — orphaned records are bugs waiting to happen.
3. **Prefer `has_many :through` over `has_and_belongs_to_many`** — every time. HABTM is a dead end you'll regret.
4. **Bi-directional by default** — declare both sides. Use `inverse_of` when Rails can't infer it.
5. **Eager load aggressively** — N+1 queries are the #1 performance killer in Rails apps.
6. **Database constraints back up model associations** — foreign keys, indexes, and unique constraints belong in migrations, not just models.

## When To Use This Skill

- Defining relationships between models (one-to-one, one-to-many, many-to-many)
- Creating migrations with foreign keys and join tables
- Fixing N+1 query problems
- Setting up polymorphic or self-referential associations
- Choosing between `has_many :through` and HABTM
- Adding counter caches
- Debugging association-related errors

## Instructions

### Step 1: Identify the Relationship Type

Before writing any code, determine the relationship:

| Relationship | Parent Model | Child Model | FK Location |
|---|---|---|---|
| One-to-many | `has_many :children` | `belongs_to :parent` | Child table |
| One-to-one | `has_one :child` | `belongs_to :parent` | Child table |
| Many-to-many | `has_many :others, through: :join` | `has_many :others, through: :join` | Join table |
| Polymorphic | `has_many :things, as: :thingable` | `belongs_to :thingable, polymorphic: true` | Child table (`_id` + `_type`) |
| Self-referential | `has_many :children, class_name: "Self"` | `belongs_to :parent, class_name: "Self"` | Same table |

**The golden rule:** `belongs_to` goes on the model whose table has the foreign key column.

### Step 2: Check Existing Patterns

**Look at the existing codebase first** — existing patterns tell you what conventions to follow:

```bash
# Find existing associations
rg "has_many\|has_one\|belongs_to\|has_and_belongs_to_many" app/models/

# Check existing migrations for FK patterns
rg "add_reference\|t.belongs_to\|t.references\|foreign_key" db/migrate/

# Look at schema
cat db/schema.rb | grep -A5 "create_table"
```

**Match existing project conventions** for naming, dependent options, and index patterns.

### Step 3: Write the Association

#### One-to-Many (most common)

```ruby
# app/models/author.rb
class Author < ApplicationRecord
  has_many :books, dependent: :destroy
end

# app/models/book.rb
class Book < ApplicationRecord
  belongs_to :author
end
```

Migration:
```ruby
class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.references :author, null: false, foreign_key: true
      t.string :title
      t.timestamps
    end
  end
end
```

#### One-to-One

```ruby
class User < ApplicationRecord
  has_one :profile, dependent: :destroy
end

class Profile < ApplicationRecord
  belongs_to :user
end
```

Migration — add a **unique** index:
```ruby
create_table :profiles do |t|
  t.references :user, null: false, foreign_key: true, index: { unique: true }
  t.timestamps
end
```

#### Many-to-Many (always use `has_many :through`)

```ruby
class Doctor < ApplicationRecord
  has_many :appointments, dependent: :destroy
  has_many :patients, through: :appointments
end

class Appointment < ApplicationRecord
  belongs_to :doctor
  belongs_to :patient
end

class Patient < ApplicationRecord
  has_many :appointments, dependent: :destroy
  has_many :doctors, through: :appointments
end
```

Migration — the join model gets its own table with a primary key:
```ruby
create_table :appointments do |t|
  t.references :doctor, null: false, foreign_key: true
  t.references :patient, null: false, foreign_key: true
  t.datetime :scheduled_at
  t.timestamps
end
```

### Step 4: Set `dependent:` on Every Association

Every `has_many` and `has_one` needs a `dependent:` option — without one, deleting a parent leaves orphaned child records with dangling foreign keys.

| Option | When to Use |
|---|---|
| `dependent: :destroy` | **Default choice.** Runs callbacks on children. Use when children have their own associations or callbacks. |
| `dependent: :delete_all` | Performance optimization. Skips callbacks. Use for leaf nodes with no further associations. |
| `dependent: :nullify` | Keep the child records but remove the association. FK must allow NULL. |
| `dependent: :restrict_with_error` | Prevent deletion if children exist. Business rule enforcement. |
| `dependent: :destroy_async` | Large datasets. Enqueues background job. Requires Active Job. Don't use with DB-level FK constraints. |

```ruby
# Missing dependent — orphaned records when author is destroyed
has_many :books

# Fixed — children cleaned up properly
has_many :books, dependent: :destroy
```

**On `belongs_to`:** Don't set `dependent:` on `belongs_to` — it causes confusion and can lead to circular destruction.

### Step 5: Handle Eager Loading (Kill N+1)

**The Problem:**
```ruby
# N+1 — fires 1 query for authors + N queries for books
Author.all.each { |a| puts a.books.count }
```

**The Fix — use `includes`:**
```ruby
# 2 queries total — always
Author.includes(:books).each { |a| puts a.books.count }
```

**When to use which:**

| Method | SQL Strategy | Use When |
|---|---|---|
| `includes` | **Smart default.** Uses `preload` or `eager_load` depending on whether you reference the association in conditions. | Most cases. Start here. |
| `preload` | Separate queries (`SELECT * FROM books WHERE author_id IN (...)`) | You want separate queries. Can't use for filtering. |
| `eager_load` | Single LEFT JOIN | You need to filter/order by associated columns in WHERE or ORDER BY. |
| `strict_loading` | Raises if lazy-loaded | Prevent N+1 at the model level during development. |

```ruby
# Filter by association column — must use eager_load (or includes handles it)
Author.includes(:books).where(books: { published: true })

# Nested eager loading
Author.includes(books: :reviews)

# Strict loading on a model (development safety net)
class Author < ApplicationRecord
  self.strict_loading_by_default = true  # Rails 7+
  has_many :books, dependent: :destroy
end

# Strict loading on a query
Author.strict_loading.all
```

### Step 6: Use `inverse_of` When Needed

Rails auto-detects inverse associations in simple cases. **You need `inverse_of` when:**

- You use `:foreign_key` or `:class_name`
- You have scoped associations
- You use `:through` associations

```ruby
# Rails CAN'T auto-detect this — specify inverse_of
class Author < ApplicationRecord
  has_many :books, inverse_of: :writer
end

class Book < ApplicationRecord
  belongs_to :writer, class_name: "Author", foreign_key: "author_id"
end
```

**Why it matters:** Without correct inverse_of, you get:
- Extra queries (N+1 for already-loaded data)
- Inconsistent in-memory objects
- Failed presence validations on new records

### Step 7: Write the Migration

**Every association needs a corresponding migration.** Associations don't create database columns.

**Always include:**
1. **Foreign key column** — use `t.references` or `add_reference`
2. **Database-level foreign key constraint** — `foreign_key: true`
3. **Index** — automatic with `t.references`, but verify
4. **NOT NULL constraint** — unless the association is `optional: true`

```ruby
# New table
create_table :books do |t|
  t.references :author, null: false, foreign_key: true
  t.timestamps
end

# Adding to existing table
add_reference :books, :author, null: false, foreign_key: true
```

**For polymorphic:**
```ruby
t.references :commentable, polymorphic: true, null: false
# Creates: commentable_id (bigint) + commentable_type (string) + composite index
```

## Common Mistakes (and Fixes)

### 1. FK on the Wrong Table

```ruby
# Wrong — puts FK on authors table (authors don't have book_id!)
class Author < ApplicationRecord
  belongs_to :book  # ← backwards
end

# Correct — books table has author_id
class Book < ApplicationRecord
  belongs_to :author
end
```

**Rule:** The table with the `_id` column gets `belongs_to`.

### 2. Missing `dependent:` on `has_many`

```ruby
# Destroys author, leaves orphaned books with dangling author_id
class Author < ApplicationRecord
  has_many :books  # ← missing dependent
end

# Fixed
class Author < ApplicationRecord
  has_many :books, dependent: :destroy
end
```

### 3. Using HABTM Instead of `has_many :through`

```ruby
# Avoid — can't add attributes, callbacks, or validations to the join
class Student < ApplicationRecord
  has_and_belongs_to_many :courses
end

# Better — flexible, extensible, future-proof
class Student < ApplicationRecord
  has_many :enrollments, dependent: :destroy
  has_many :courses, through: :enrollments
end

class Enrollment < ApplicationRecord
  belongs_to :student
  belongs_to :course
  # Now you can add: grade, enrolled_at, status, etc.
end
```

### 4. Polymorphic When You Shouldn't

**Use polymorphic when:**
- Multiple unrelated models need the same child (comments, attachments, tags)
- You're building a framework/engine feature

**Don't use polymorphic when:**
- Only 2-3 specific models — use separate FKs instead
- You need database-level referential integrity (polymorphic FKs can't have DB constraints)
- You need to join across the polymorphic boundary efficiently

```ruby
# Polymorphic is overkill here — just use two belongs_to
class Comment < ApplicationRecord
  belongs_to :post     # Better than polymorphic if only commenting on posts and articles
  belongs_to :article
end
```

### 5. N+1 in Views

```ruby
# Controller — forgot to eager load
def index
  @posts = Post.all  # N+1 when view calls post.author.name
end

# Fixed
def index
  @posts = Post.includes(:author, :comments)
end
```

### 6. `optional: true` Without Reason

```ruby
# belongs_to validates presence by default (Rails 5+)
# Don't add optional: true unless the FK is genuinely nullable
belongs_to :author                    # Validates author exists ✓
belongs_to :author, optional: true    # Only if author_id can be NULL
```

## Quick Reference

### Association Cheat Sheet

```ruby
# One-to-many
has_many :posts, dependent: :destroy
belongs_to :user

# One-to-one
has_one :profile, dependent: :destroy
belongs_to :user

# Many-to-many (through)
has_many :taggings, dependent: :destroy
has_many :tags, through: :taggings

# Polymorphic
has_many :comments, as: :commentable, dependent: :destroy
belongs_to :commentable, polymorphic: true

# Self-referential
has_many :subordinates, class_name: "Employee", foreign_key: "manager_id", dependent: :nullify
belongs_to :manager, class_name: "Employee", optional: true

# Counter cache (declare on belongs_to side, column on has_many side)
belongs_to :author, counter_cache: true
# Requires: add_column :authors, :books_count, :integer, default: 0, null: false

# Scoped association
has_many :published_books, -> { where(published: true) }, class_name: "Book", dependent: :destroy

# With ordering
has_many :books, -> { order(created_at: :desc) }, dependent: :destroy
```

### Migration Patterns

```ruby
# Standard FK
t.references :author, null: false, foreign_key: true

# Polymorphic FK
t.references :commentable, polymorphic: true, null: false

# Self-referential FK
t.references :manager, foreign_key: { to_table: :employees }

# Custom FK name
t.bigint :creator_id
add_foreign_key :posts, :users, column: :creator_id

# Join table for has_many :through
create_table :enrollments do |t|
  t.references :student, null: false, foreign_key: true
  t.references :course, null: false, foreign_key: true
  t.timestamps
end
add_index :enrollments, [:student_id, :course_id], unique: true
```

### Eager Loading Decision Tree

```
Need to filter/order by associated columns?
  YES → includes (auto-detects) or eager_load (explicit LEFT JOIN)
  NO  → includes (auto-detects) or preload (explicit separate queries)

Need nested associations?
  → Author.includes(books: [:reviews, :publisher])

Want to prevent N+1 entirely?
  → strict_loading (model or query level)
```

### `belongs_to` Options Quick Reference

| Option | Default | Purpose |
|---|---|---|
| `optional: true` | `false` | Allow NULL foreign key |
| `counter_cache: true` | `false` | Maintain count column on parent |
| `touch: true` | `false` | Update parent's `updated_at` on save |
| `polymorphic: true` | `false` | Polymorphic association |
| `class_name:` | Inferred | Specify non-standard class |
| `foreign_key:` | `"#{name}_id"` | Specify non-standard FK column |
| `inverse_of:` | Auto-detected | Specify inverse association name |

### `has_many` / `has_one` Options Quick Reference

| Option | Default | Purpose |
|---|---|---|
| `dependent:` | None | **Always set this.** See Step 4. |
| `class_name:` | Inferred | Non-standard class name |
| `foreign_key:` | `"#{model}_id"` | Non-standard FK column |
| `inverse_of:` | Auto-detected | Specify inverse association |
| `through:` | None | Through association |
| `source:` | Inferred | Source association name for `:through` |
| `as:` | None | Polymorphic interface name |
| `counter_cache:` | None | (has_many only) read counter cache column |

## Debugging Associations

```ruby
# Check what associations a model has
Author.reflect_on_all_associations.map { |a| [a.macro, a.name] }

# Check a specific association
Author.reflect_on_association(:books)

# See the SQL an association generates
Author.first.books.to_sql

# Check if inverse is set
Author.reflect_on_association(:books).inverse_of

# Find orphaned records
Book.left_joins(:author).where(authors: { id: nil })

# Reset counter cache
Author.reset_counters(author_id, :books)
```

## Anti-Patterns to Avoid

1. **No `dependent:` on `has_many`/`has_one`** — orphaned records cause subtle data bugs
2. **HABTM** — use `has_many :through` instead; HABTM can't hold attributes, validations, or callbacks on the join
3. **Missing database constraints** — `foreign_key: true` in migrations
4. **Lazy loading in loops** — use `includes` / `preload` / `eager_load`
5. **Polymorphic for 2 models** — just use separate foreign keys
6. **`optional: true` by default** — only when the FK is genuinely nullable
7. **Missing `inverse_of`** — when using custom `:foreign_key` or `:class_name`
8. **No unique index on `has_one` FK** — allows duplicate records without it
9. **Forgetting the migration** — associations don't create columns
10. **`dependent: :destroy` on huge collections** — use `:delete_all` or `:destroy_async`

For detailed patterns, options reference, and advanced examples, see the `references/` directory:
- `references/association-types.md` — Deep dive into belongs_to, has_one, has_many, has_many :through, HABTM
- `references/polymorphic.md` — Polymorphic associations, STI, and delegated types
- `references/self-referential.md` — Tree structures, manager-employee, social follows
- `references/eager-loading.md` — includes/preload/eager_load strategies, inverse_of
- `references/counter-caches.md` — Counter caches, scoped associations, callbacks, extensions
- `references/testing.md` — Testing patterns, migration examples, performance tips, troubleshooting
