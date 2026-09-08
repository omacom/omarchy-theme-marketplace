# Polymorphic Associations, STI & Delegated Types

Patterns for when models need to relate to multiple different types.

---

## Polymorphic Associations

A model belongs to multiple other models via a single association.

```ruby
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
end

class Article < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
end
```

**Migration:**
```ruby
create_table :comments do |t|
  t.text :body
  t.references :commentable, polymorphic: true, null: false
  # Creates: commentable_id (bigint), commentable_type (string)
  # Creates: index on [commentable_type, commentable_id]
  t.timestamps
end
```

### When to Use Polymorphic

**Good use cases:**
- Comments on many different models
- Attachments/uploads shared across models
- Activity logs / audit trails
- Tags / taggings
- Notifications referencing various sources

**Bad use cases (don't use polymorphic):**
- Only 2-3 specific models — use separate FKs instead
- You need database-level foreign key constraints (can't add FK on polymorphic)
- You need efficient JOINs across the polymorphic boundary
- The "types" are actually related (consider STI or delegated types)

### `has_many :through` with Polymorphic Source

```ruby
class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings, source: :taggable, source_type: "Post"
  has_many :articles, through: :taggings, source: :taggable, source_type: "Article"
end

class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :taggable, polymorphic: true
end

class Post < ApplicationRecord
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings
end
```

**Note:** The `through` association itself cannot be polymorphic, but the `source` can be.

---

## Single Table Inheritance (STI)

Multiple models in one table, differentiated by a `type` column.

```ruby
class Vehicle < ApplicationRecord
  # type column stores "Car", "Truck", "Motorcycle"
end

class Car < Vehicle
  has_many :doors, dependent: :destroy  # STI models can have their own associations
end

class Truck < Vehicle
  has_many :cargo_holds, dependent: :destroy
end
```

**When to use STI:**
- Subclasses share most attributes
- You query across types frequently (`Vehicle.all`)
- Differences are mostly behavioral (methods), not structural (columns)

**When NOT to use STI:**
- Subclasses have very different attributes (table bloat with NULLs)
- You rarely query across types
- Consider delegated types instead

**STI + Associations:**
```ruby
# Associating with an STI model
class Fleet < ApplicationRecord
  has_many :vehicles, dependent: :destroy
  has_many :cars    # Automatically scoped: WHERE type = 'Car'
  has_many :trucks  # Automatically scoped: WHERE type = 'Truck'
end
```

**Gotcha — custom inheritance column:**
```ruby
class Vehicle < ApplicationRecord
  self.inheritance_column = "kind"  # Use "kind" instead of "type"
end
```

**Gotcha — disabling STI:**
```ruby
class Vehicle < ApplicationRecord
  self.inheritance_column = nil  # Disable STI entirely
end
```

---

## Delegated Types

Alternative to STI that avoids table bloat. Shared attributes in superclass table, type-specific attributes in separate tables.

```ruby
class Entry < ApplicationRecord
  delegated_type :entryable, types: %w[Message Comment], dependent: :destroy
end

module Entryable
  extend ActiveSupport::Concern
  included do
    has_one :entry, as: :entryable, touch: true
  end
end

class Message < ApplicationRecord
  include Entryable
  # Has its own table with message-specific columns
end

class Comment < ApplicationRecord
  include Entryable
  # Has its own table with comment-specific columns
end
```

**When to use delegated types vs STI:**
- STI: Models share 80%+ of attributes
- Delegated types: Models share some attributes but have many unique ones
