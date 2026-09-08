# Eager Loading Strategies & inverse_of

Preventing N+1 queries and keeping associations bi-directional.

---

## Eager Loading Strategies

### `includes` (Smart Default)

```ruby
# Separate queries (preload strategy)
Author.includes(:books)
# SELECT * FROM authors
# SELECT * FROM books WHERE author_id IN (1, 2, 3, ...)

# Switches to LEFT JOIN when filtering by association
Author.includes(:books).where(books: { published: true })
# SELECT authors.*, books.* FROM authors LEFT JOIN books ON ...
```

### `preload` (Always Separate Queries)

```ruby
Author.preload(:books)
# Always: SELECT * FROM authors
#         SELECT * FROM books WHERE author_id IN (...)

# Can't filter by association — raises error:
Author.preload(:books).where(books: { published: true })
# => ActiveRecord::StatementInvalid
```

### `eager_load` (Always LEFT JOIN)

```ruby
Author.eager_load(:books)
# Always: SELECT authors.*, books.*
#         FROM authors LEFT OUTER JOIN books ON ...

# Can filter by association:
Author.eager_load(:books).where(books: { published: true })
```

### Nested Eager Loading

```ruby
# Multiple associations
Author.includes(:books, :profile)

# Nested associations
Author.includes(books: :reviews)

# Deep nesting
Author.includes(books: [reviews: :reviewer, publisher: :address])

# Mixed
Author.includes(:profile, books: [:reviews, :tags])
```

### `strict_loading` (Prevent N+1)

```ruby
# On a query
authors = Author.strict_loading.all
authors.first.books  # => ActiveRecord::StrictLoadingViolationError

# On a model (all queries)
class Author < ApplicationRecord
  self.strict_loading_by_default = true
end

# On a specific association
class Author < ApplicationRecord
  has_many :books, strict_loading: true, dependent: :destroy
end

# On a record
author = Author.first
author.strict_loading!
author.books  # => raises
```

### Preload in Batches

```ruby
# For very large collections
Author.find_each do |author|
  # Still N+1 — find_each doesn't support includes
end

# Use in_batches instead
Author.includes(:books).in_batches(of: 100) do |batch|
  batch.each { |author| process(author) }
end
```

---

## Bi-directional Associations & inverse_of

### When Rails Auto-Detects

```ruby
# Auto-detected — no inverse_of needed
class Author < ApplicationRecord
  has_many :books
end
class Book < ApplicationRecord
  belongs_to :author
end

author = Author.first
book = author.books.first
book.author.equal?(author)  # => true (same object in memory)
```

### When You Must Specify `inverse_of`

```ruby
# Custom foreign_key — NOT auto-detected
class Author < ApplicationRecord
  has_many :books, foreign_key: "writer_id", inverse_of: :writer
end
class Book < ApplicationRecord
  belongs_to :writer, class_name: "Author", foreign_key: "writer_id", inverse_of: :books
end

# Custom class_name — NOT auto-detected
class Author < ApplicationRecord
  has_many :publications, class_name: "Book", inverse_of: :author
end

# Scoped association — NOT auto-detected (unless automatic_scope_inversing is true)
class Author < ApplicationRecord
  has_many :published_books, -> { where(published: true) }, class_name: "Book", inverse_of: :author
end
```

### What Breaks Without Correct inverse_of

1. **Extra queries:** `book.author` fires a new query even when author is loaded
2. **Inconsistent data:** Modifying `author.name` isn't reflected in `book.author.name`
3. **Failed autosave:** Building `author.books.new` then saving book doesn't save author
4. **Failed presence validation:** `book.valid?` says "Author must exist" even when built from `author.books.new`

### Enable Automatic Scope Inversing

```ruby
# config/application.rb
config.active_record.automatic_scope_inversing = true
# Now scoped associations auto-detect inverse_of
```
