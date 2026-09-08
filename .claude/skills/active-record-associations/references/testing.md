# Testing, Migrations, Performance & Troubleshooting

Practical patterns for testing associations, writing migrations, optimizing performance, and fixing common issues.

---

## Migration Patterns

### Standard Foreign Key

```ruby
# In create_table
t.references :author, null: false, foreign_key: true

# Adding to existing table
add_reference :books, :author, null: false, foreign_key: true

# These are equivalent:
t.references :author
t.belongs_to :author
```

### Polymorphic Foreign Key

```ruby
t.references :commentable, polymorphic: true, null: false
# Creates: commentable_id, commentable_type, composite index

# Manual equivalent:
t.bigint :commentable_id, null: false
t.string :commentable_type, null: false
add_index :comments, [:commentable_type, :commentable_id]
```

### Self-Referential Foreign Key

```ruby
t.references :parent, foreign_key: { to_table: :categories }
# to_table is REQUIRED for self-joins
```

### Custom Foreign Key Name

```ruby
t.bigint :creator_id, null: false
add_foreign_key :posts, :users, column: :creator_id
add_index :posts, :creator_id
```

### Join Table for `has_many :through`

```ruby
create_table :taggings do |t|
  t.references :tag, null: false, foreign_key: true
  t.references :article, null: false, foreign_key: true
  t.timestamps
end
add_index :taggings, [:tag_id, :article_id], unique: true
```

### Unique Index for `has_one`

```ruby
t.references :user, null: false, foreign_key: true, index: { unique: true }
```

---

## Testing Associations

### Model Test (Minitest)

```ruby
class AuthorTest < ActiveSupport::TestCase
  test "has many books" do
    author = authors(:prolific_author)
    assert_respond_to author, :books
    assert_kind_of ActiveRecord::Associations::CollectionProxy, author.books
  end

  test "destroying author destroys books" do
    author = authors(:prolific_author)
    book_count = author.books.count
    assert_operator book_count, :>, 0

    assert_difference "Book.count", -book_count do
      author.destroy
    end
  end

  test "book requires author" do
    book = Book.new(title: "Orphan")
    refute book.valid?
    assert_includes book.errors[:author], "must exist"
  end
end
```

### Testing Eager Loading

```ruby
test "index eager loads authors" do
  assert_queries_count(2) do  # 1 for posts, 1 for authors
    Post.includes(:author).to_a
  end
end
```

### Testing Counter Cache

```ruby
test "books_count reflects actual count" do
  author = authors(:prolific_author)
  assert_equal author.books.count, author.books_count

  assert_difference -> { author.reload.books_count }, 1 do
    author.books.create!(title: "New Book")
  end
end
```

---

## Performance Patterns

### Batch Preloading

```ruby
# Preload after the fact (useful in service objects)
posts = Post.limit(100).to_a
ActiveRecord::Associations::Preloader.new(
  records: posts,
  associations: [:author, :comments]
).call
```

### Avoiding `.count` on Large Collections

```ruby
# SLOW — COUNT query every time
author.books.count

# FAST — uses counter cache
author.books.size  # When counter_cache is configured

# FAST — just check existence
author.books.any?     # EXISTS query
author.books.empty?   # EXISTS query (negated)
author.books.exists?  # EXISTS query
```

### Pluck Instead of Load

```ruby
# SLOW — loads all Book objects into memory
author.books.map(&:id)

# FAST — only fetches IDs
author.book_ids

# FAST — select specific columns
author.books.pluck(:id, :title)
```

### Conditional Eager Loading

```ruby
# Only eager load when you'll use it
scope = Post.all
scope = scope.includes(:author) if params[:include_author]
scope = scope.includes(:comments) if params[:include_comments]
```

---

## Troubleshooting

### "uninitialized constant" Error

You used plural when you needed singular (or vice versa):
```ruby
belongs_to :authors    # WRONG — should be :author
has_many :book         # WRONG — should be :books
```

### "Cannot find inverse" Warning

Add explicit `inverse_of:`:
```ruby
has_many :books, foreign_key: "writer_id", inverse_of: :writer
```

### Foreign Key Violation on Delete

You're missing `dependent:` or using the wrong option:
```ruby
# If FK constraint is NOT NULL
has_many :books, dependent: :destroy  # or :delete_all

# If FK constraint allows NULL
has_many :books, dependent: :nullify
```

### Counter Cache Out of Sync

```ruby
Author.reset_counters(author_id, :books)
# Or reset all:
Author.find_each { |a| Author.reset_counters(a.id, :books) }
```

### Polymorphic Association Renamed Class

When you rename a class used in polymorphic associations:
```ruby
class RenameProductToItem < ActiveRecord::Migration[8.1]
  def up
    # Must update the type column!
    Picture.where(imageable_type: "Product").update_all(imageable_type: "Item")
  end
end
```

### N+1 in Serializers / Jbuilder

```ruby
# Controller must eager load what the view/serializer needs
def index
  @posts = Post.includes(author: :profile, comments: :user)
end
```

### `touch: true` Cascading Slowly

If `touch: true` cascades through many levels, consider:
```ruby
# Use touch: false and handle manually
belongs_to :author, touch: false

# Or batch touch in a callback
after_commit :touch_author
def touch_author
  author.touch
end
```

### Association Scope Not Applied on Create

Only hash-style `where` scopes auto-apply on create:
```ruby
# Auto-applies published: true on create
has_many :published_books, -> { where(published: true) }, class_name: "Book"

# Does NOT auto-apply (string condition)
has_many :recent_books, -> { where("created_at > ?", 1.week.ago) }, class_name: "Book"
```
