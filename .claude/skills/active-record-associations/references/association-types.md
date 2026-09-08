# Association Types Deep Dive

Detailed reference for each Rails association type — methods, options, and behaviors.

## `belongs_to`

The child side of any relationship. The table with the FK column declares `belongs_to`.

```ruby
class Book < ApplicationRecord
  belongs_to :author
end
```

**Key behaviors:**
- Validates presence by default (Rails 5+). Use `optional: true` to allow NULL.
- Does NOT auto-save the parent. Saving the child saves the FK, not the parent object.
- `build_author` / `create_author` — note the `build_` prefix (not `author.build`).

**All methods added:**
```ruby
book.author                        # Get associated author (cached)
book.author = author               # Set association (updates FK)
book.build_author(attrs)           # Build unsaved author
book.create_author(attrs)          # Build + save author
book.create_author!(attrs)         # Build + save, raise on invalid
book.reload_author                 # Force reload from DB
book.reset_author                  # Clear cache, lazy reload next access
book.author_changed?               # FK will change on next save?
book.author_previously_changed?    # FK changed on last save?
```

**Options reference:**

| Option | Description |
|---|---|
| `class_name: "Patron"` | Non-standard class name |
| `foreign_key: "patron_id"` | Non-standard FK column |
| `primary_key: "guid"` | Parent's PK isn't `id` |
| `polymorphic: true` | Polymorphic — stores type + id |
| `optional: true` | Allow NULL FK (skip presence validation) |
| `touch: true` | Update parent's `updated_at` on save/destroy |
| `touch: :books_updated_at` | Touch a specific timestamp column |
| `counter_cache: true` | Maintain count on parent (column: `#{table}_count`) |
| `counter_cache: :num_books` | Custom counter cache column name |
| `inverse_of: :books` | Explicit inverse association |
| `default: -> { Current.user }` | Default value for new records |
| `strict_loading: true` | Raise on lazy load |

## `has_one`

The parent side of a one-to-one relationship. FK lives on the **other** table.

```ruby
class User < ApplicationRecord
  has_one :profile, dependent: :destroy
end

class Profile < ApplicationRecord
  belongs_to :user
end
```

**Key behaviors:**
- Assigning a new object auto-saves it AND nullifies/destroys the old one.
- Always add a **unique index** on the FK column to enforce one-to-one at the DB level.
- Uses `build_profile` / `create_profile` (not `profile.build`).

**When to use `has_one` vs `belongs_to`:**
- Ask: "Who owns whom?" The owner gets `has_one`. The owned gets `belongs_to`.
- The FK column is always on the `belongs_to` table.

## `has_many`

The parent side of a one-to-many relationship.

```ruby
class Author < ApplicationRecord
  has_many :books, dependent: :destroy
end
```

**Key collection methods:**
```ruby
author.books                       # CollectionProxy (lazy)
author.books.load                  # Force load, cache result
author.books.reload                # Force reload from DB
author.books.size                  # Uses counter cache if available, else COUNT
author.books.count                 # Always COUNT query
author.books.length                # Loads all, counts in memory
author.books.empty?                # Uses counter cache or EXISTS
author.books.any?                  # Uses counter cache or EXISTS
author.books.exists?(id: 5)       # EXISTS query
author.books.find(id)             # Find within association
author.books.where(published: true) # Scoped query (lazy)
author.books.build(attrs)         # Build unsaved (note: .build, not build_)
author.books.create(attrs)        # Build + save
author.books.create!(attrs)       # Build + save, raise on invalid
author.books << book              # Add to collection, saves immediately
author.books.delete(book)         # Remove (nullify FK or delete)
author.books.destroy(book)        # Remove + destroy record
author.books.clear                # Remove all (strategy depends on dependent:)
author.book_ids                   # Array of IDs
author.book_ids = [1, 2, 3]      # Assign by IDs (adds/removes as needed)
```

**`size` vs `count` vs `length`:**
- `size` — smartest choice. Uses counter cache if available, loaded collection if already loaded, else COUNT query.
- `count` — always fires a COUNT query. Ignores cache.
- `length` — loads ALL records into memory, counts them. Wasteful for large collections.

## `has_many :through`

Many-to-many via a join model. **Always prefer this over HABTM.**

```ruby
class Doctor < ApplicationRecord
  has_many :appointments, dependent: :destroy
  has_many :patients, through: :appointments
end

class Appointment < ApplicationRecord
  belongs_to :doctor
  belongs_to :patient
  # Can have extra attributes: scheduled_at, notes, status, etc.
end

class Patient < ApplicationRecord
  has_many :appointments, dependent: :destroy
  has_many :doctors, through: :appointments
end
```

**Why always `:through`?**
1. You can add attributes to the join (timestamps, status, metadata)
2. You can add validations and callbacks to the join model
3. You can query the join model independently
4. You can use `dependent:` options
5. Every HABTM eventually needs to become a `:through` anyway

**Nested through (shortcut associations):**
```ruby
class Country < ApplicationRecord
  has_many :states, dependent: :destroy
  has_many :cities, through: :states  # Shortcut through nested has_many
end

class State < ApplicationRecord
  belongs_to :country
  has_many :cities, dependent: :destroy
end

class City < ApplicationRecord
  belongs_to :state
  has_one :country, through: :state  # has_one :through for the inverse
end
```

**`source:` option — when Rails can't infer the source:**
```ruby
class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships, source: :team
  # source: :team tells Rails: Membership.belongs_to(:team) is the source
end

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :team  # Name doesn't match "groups" — need source:
end
```

## `has_and_belongs_to_many` (HABTM) — Don't Use

Exists for legacy compatibility. **Always use `has_many :through` instead.**

If you encounter HABTM in existing code:
```ruby
# Legacy HABTM
class Assembly < ApplicationRecord
  has_and_belongs_to_many :parts
end

# Convert to has_many :through
class Assembly < ApplicationRecord
  has_many :assembly_parts, dependent: :destroy
  has_many :parts, through: :assembly_parts
end

class AssemblyPart < ApplicationRecord
  belongs_to :assembly
  belongs_to :part
end
```

Migration to convert (add model to join table):
```ruby
class AddIdToAssembliesParts < ActiveRecord::Migration[8.1]
  def change
    # Add primary key and timestamps to existing join table
    add_column :assemblies_parts, :id, :primary_key
    add_timestamps :assemblies_parts
    # Rename to follow convention (plural of join model)
    rename_table :assemblies_parts, :assembly_parts
  end
end
```
