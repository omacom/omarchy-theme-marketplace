# Counter Caches, Scoped Associations, Callbacks & Extensions

Optimizing counts, filtering associations, and extending collection behavior.

---

## Counter Caches

Avoid `COUNT(*)` queries by caching the count in a column.

### Setup

```ruby
# 1. Declare on belongs_to side
class Book < ApplicationRecord
  belongs_to :author, counter_cache: true
end

class Author < ApplicationRecord
  has_many :books, dependent: :destroy
end

# 2. Add column to parent table
class AddBooksCountToAuthors < ActiveRecord::Migration[8.1]
  def change
    add_column :authors, :books_count, :integer, default: 0, null: false
  end
end

# 3. Backfill existing data
class BackfillBooksCount < ActiveRecord::Migration[8.1]
  def up
    Author.find_each do |author|
      Author.reset_counters(author.id, :books)
    end
  end
end
```

### Custom Column Name

```ruby
belongs_to :author, counter_cache: :num_books
# Column must be: authors.num_books
```

### Safe Backfill Pattern

For large tables, use `counter_cache: { active: false }` during backfill:

```ruby
# During backfill — always hits DB for count
belongs_to :author, counter_cache: { active: false }

# After backfill complete — uses cached value
belongs_to :author, counter_cache: true
```

### Resetting Stale Counters

```ruby
# Reset for one record
Author.reset_counters(author.id, :books)

# Reset all
Author.find_each { |a| Author.reset_counters(a.id, :books) }
```

---

## Scoped Associations

Add conditions to associations.

```ruby
class Author < ApplicationRecord
  has_many :books, dependent: :destroy
  has_many :published_books, -> { where(published: true) },
           class_name: "Book", dependent: :destroy
  has_many :recent_books, -> { where("created_at > ?", 30.days.ago) },
           class_name: "Book", dependent: :destroy
  has_many :books_by_title, -> { order(:title) },
           class_name: "Book", dependent: :destroy
end
```

**With owner context (prevents preloading):**
```ruby
class Supplier < ApplicationRecord
  has_one :account, ->(supplier) { where(active: supplier.active?) }
  # WARNING: Can't preload this because scope depends on owner
end
```

**Hash conditions auto-apply on create:**
```ruby
has_many :published_books, -> { where(published: true) }, class_name: "Book"

author.published_books.create(title: "New Book")
# Automatically sets published: true
```

**Scoped `has_many :through` with `distinct`:**
```ruby
class Person < ApplicationRecord
  has_many :readings, dependent: :destroy
  has_many :articles, -> { distinct }, through: :readings
end
```

---

## Association Callbacks

Triggered when objects are added to or removed from a collection.

```ruby
class Author < ApplicationRecord
  has_many :books, dependent: :destroy,
           before_add: :check_limit,
           after_add: :notify_subscribers,
           before_remove: :log_removal,
           after_remove: :update_stats

  private

  def check_limit(book)
    throw(:abort) if books.count >= 100
  end

  def notify_subscribers(book)
    AuthorSubscriptionMailer.new_book(self, book).deliver_later
  end

  def log_removal(book)
    Rails.logger.info "Removing #{book.title} from #{name}"
  end

  def update_stats(book)
    recalculate_stats!
  end
end
```

**Available callbacks:**
- `before_add` — before adding to collection. `throw(:abort)` to prevent.
- `after_add` — after adding to collection.
- `before_remove` — before removing from collection.
- `after_remove` — after removing from collection.

**Multiple callbacks:**
```ruby
has_many :books, before_add: [:check_limit, :validate_genre]
```

---

## Association Extensions

Add custom methods to association proxies.

### Inline Extension

```ruby
class Author < ApplicationRecord
  has_many :books, dependent: :destroy do
    def published
      where(published: true)
    end

    def by_year(year)
      where("EXTRACT(YEAR FROM published_at) = ?", year)
    end

    def find_by_isbn(isbn)
      find_by(isbn: isbn)
    end
  end
end

# Usage
author.books.published
author.books.by_year(2024)
author.books.find_by_isbn("978-0-123456-78-9")
```

### Shared Extension Module

```ruby
module FindRecentExtension
  def recent(days = 30)
    where("created_at > ?", days.days.ago)
  end
end

class Author < ApplicationRecord
  has_many :books, -> { extending FindRecentExtension }, dependent: :destroy
end

class Publisher < ApplicationRecord
  has_many :editions, -> { extending FindRecentExtension }, dependent: :destroy
end
```

### Accessing Proxy Internals

```ruby
module AdvancedExtension
  def search_and_log(query)
    results = where(title: query)
    owner = proxy_association.owner
    assoc_name = proxy_association.reflection.name
    Rails.logger.info "#{owner.class}##{assoc_name}: searched '#{query}', found #{results.size}"
    results
  end
end
```
