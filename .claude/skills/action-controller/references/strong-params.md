# Strong Parameters Deep Dive

Detailed patterns and edge cases for Rails strong parameters.

## expect vs require + permit

Rails 8 introduced `expect` which combines `require` and `permit` into one call. Prefer `expect`.

```ruby
# Rails 8+ (preferred)
params.expect(article: [:title, :body])

# Equivalent older style
params.require(:article).permit(:title, :body)
```

`expect` raises `ActionController::ParameterMissing` (returns 400) if the root key is missing.

## Scalar values from params

```ruby
# Extract a single scalar (e.g., from URL params)
id = params.expect(:id)    # raises if :id missing

# Old style
id = params.require(:id)
```

## All Permitting Patterns

### Simple flat attributes
```ruby
params.expect(user: [:name, :email, :age, :active])
```

### Array of scalars (tag_ids, category_ids, etc.)
```ruby
# { article: { title: "Hi", tag_ids: [1, 2, 3] } }
params.expect(article: [:title, tag_ids: []])
```

### Single nested hash (belongs_to / has_one style)
```ruby
# { user: { name: "Jo", profile: { bio: "Hi", website: "example.com" } } }
params.expect(user: [:name, profile: [:bio, :website]])
```

### Deeply nested hashes
```ruby
# { company: { name: "Acme", address: { street: "123", geo: { lat: 1.0, lng: 2.0 } } } }
params.expect(company: [:name, address: [:street, :city, geo: [:lat, :lng]]])
```

### Array of hashes (has_many nested attributes) — DOUBLE ARRAY SYNTAX
```ruby
# { project: { name: "X", tasks_attributes: [{ title: "A" }, { title: "B" }] } }
params.expect(project: [:name, tasks_attributes: [[:title, :done, :id, :_destroy]]])
```

The `[[...]]` (double array) is critical. Single `[...]` means "array of scalars." Double `[[...]]` means "array of hashes with these permitted keys."

### Hash with integer keys (nested attributes from forms)
```ruby
# Forms send: { book: { chapters_attributes: { "0" => { title: "Ch1" }, "1" => { title: "Ch2" } } } }
# Same syntax — Rails treats integer-keyed hashes like arrays
params.expect(book: [:title, chapters_attributes: [[:title, :id, :_destroy]]])
```

### Arbitrary/dynamic hash
```ruby
# When keys are truly unpredictable (settings, metadata, etc.)
params.expect(product: [:name, settings: {}])
# ⚠️ settings: {} permits ANY scalar values inside. Use only when necessary.
```

### Multiple file uploads
```ruby
# { post: { title: "Hi", images: [<file1>, <file2>] } }
params.expect(post: [:title, images: []])
```

### fetch with defaults (for optional root keys)
```ruby
# Useful in #new where the root key might not exist yet
params.fetch(:blog, {}).permit(:title, :author)
```

### accepts_nested_attributes_for — complete example
```ruby
# Model:
class Project < ApplicationRecord
  has_many :tasks
  accepts_nested_attributes_for :tasks, allow_destroy: true
end

# Controller:
def project_params
  params.expect(project: [
    :name,
    :description,
    tasks_attributes: [[:title, :completed, :position, :id, :_destroy]]
  ])
end
```

Always include `:id` and `:_destroy` for nested attributes if `allow_destroy: true`.

## Multiple return values from expect

```ruby
name, emails, friends = params.expect(
  :name,
  emails: [],
  friends: [[:name, family: [:name], hobbies: []]]
)
```

## Composite key parameters

```ruby
# URL: /books/4_2
id = params.extract_value(:id)  # => ["4", "2"]
@book = Book.find(id)
```
