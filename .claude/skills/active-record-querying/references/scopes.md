# Scopes, Overriding Conditions, and Method Chaining

## Scopes — Patterns and Pitfalls

### Basic Patterns

```ruby
class Article < ApplicationRecord
  # Simple conditions
  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }
  scope :recent, -> { order(created_at: :desc) }

  # With arguments
  scope :by_author, ->(author) { where(author: author) }
  scope :created_after, ->(date) { where(created_at: date..) }
  scope :tagged, ->(tag) { joins(:tags).where(tags: { name: tag }) }

  # Composing scopes
  scope :featured, -> { published.where(featured: true).recent }

  # With safe conditional
  scope :search, ->(query) {
    query.present? ? where("title ILIKE ?", "%#{sanitize_sql_like(query)}%") : all
  }
end

# Chain freely
Article.published.recent.by_author(user).limit(10)
Article.published.tagged("ruby").search(params[:q])
```

### Scope vs Class Method

```ruby
class Article < ApplicationRecord
  # Scope — always returns Relation (nil becomes .all)
  scope :status, ->(s) { where(status: s) if s.present? }

  # Class method — can return nil (breaks chaining!)
  def self.status(s)
    where(status: s) if s.present?  # Returns nil when s is blank!
  end

  # Fix: always return a Relation from class methods
  def self.status(s)
    return all if s.blank?
    where(status: s)
  end
end
```

**Rule:** Use scopes for simple query fragments. Use class methods for complex logic — but always return `all` as fallback, never `nil`.

### Scope on Associations

```ruby
author = Author.first
author.books.published.recent  # Scopes work on associations!
author.books.costs_more_than(50)
```

### default_scope — Avoid It

```ruby
# DON'T — this infects every query on the model
class Article < ApplicationRecord
  default_scope { where(published: true) }  # Seems helpful...
end

# Problems:
Article.new.published  # true — affects new records!
Article.count          # Only counts published
Article.joins(:comments)  # Only joins published
Article.unscoped       # You'll need this everywhere

# DO — use explicit scopes instead
class Article < ApplicationRecord
  scope :published, -> { where(published: true) }
  scope :visible, -> { published.where(hidden: false) }
end
```

### Merging Scopes

```ruby
# AND — chaining scopes ANDs them
Article.published.where(featured: true)
# WHERE published = true AND featured = true

# merge — last wins for same column
Article.published.merge(Article.draft)
# WHERE published = false (merge overrides)

# merge with association scopes (very powerful)
Customer.joins(:orders).merge(Order.created_before(1.week.ago))
```

### Removing Scopes

```ruby
# Remove all scopes (including default_scope)
Article.unscoped

# Remove specific scope type
Article.where(published: true).limit(20).unscope(:limit)

# Remove specific where condition
Article.where(id: 10, published: true).unscope(where: :id)
# WHERE published = true
```

---

## Overriding and Resetting Conditions

```ruby
# unscope — remove specific clause types
Book.where(published: true).order(:title).unscope(:order)
Book.where(id: 10, published: true).unscope(where: :id)

# only — keep only specific clauses
Book.where(published: true).order(:title).limit(10).only(:where, :order)

# reselect — replace select
Book.select(:title).reselect(:isbn)

# reorder — replace order
Book.order(:title).reorder(:created_at)

# rewhere — replace where condition
Book.where(published: true).rewhere(published: false)

# regroup — replace group
Book.group(:author).regroup(:status)

# none — empty relation (useful as fallback)
Book.none  # Chainable, returns empty relation, fires no queries

# unscoped — remove ALL scopes (including default_scope)
Book.unscoped
Book.unscoped { Book.published }  # Block form: removes default, applies published
```

---

## Method Chaining Patterns

### Building Queries Incrementally

```ruby
def index
  @posts = Post.published

  if params[:author_id].present?
    @posts = @posts.where(author_id: params[:author_id])
  end

  if params[:tag].present?
    @posts = @posts.joins(:tags).where(tags: { name: params[:tag] })
  end

  if params[:search].present?
    @posts = @posts.where("title ILIKE ?", "%#{Post.sanitize_sql_like(params[:search])}%")
  end

  @posts = @posts.order(created_at: :desc).page(params[:page])
end
```

### Query Objects (For Complex Queries)

```ruby
class PostSearch
  def initialize(params)
    @params = params
    @scope = Post.published
  end

  def results
    filter_by_author
    filter_by_tag
    filter_by_search
    apply_ordering
    @scope
  end

  private

  def filter_by_author
    return unless @params[:author_id].present?
    @scope = @scope.where(author_id: @params[:author_id])
  end

  def filter_by_tag
    return unless @params[:tag].present?
    @scope = @scope.joins(:tags).where(tags: { name: @params[:tag] }).distinct
  end

  def filter_by_search
    return unless @params[:search].present?
    @scope = @scope.where(
      "title ILIKE ?",
      "%#{Post.sanitize_sql_like(@params[:search])}%"
    )
  end

  def apply_ordering
    @scope = @scope.order(created_at: :desc)
  end
end

# Usage
posts = PostSearch.new(params).results.page(params[:page])
```
