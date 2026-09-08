# Errors API and I18n

Complete reference for reading, adding, filtering errors, and configuring error messages with I18n.

## Reading errors

```ruby
record.valid?                              # Run validations, return bool
record.invalid?                            # Inverse of valid?

record.errors                              # ActiveModel::Errors instance
record.errors.any?                         # Any errors?
record.errors.empty?                       # No errors? (alias: .none?)
record.errors.count                        # Total error count (alias: .size)
record.errors.full_messages                # ["Name can't be blank", ...]
record.errors.full_messages_for(:name)     # ["Name can't be blank", "Name is too short..."]

record.errors[:name]                       # ["can't be blank", "is too short..."]
record.errors[:name].any?                  # Errors on this attribute?

record.errors.messages                     # { name: ["can't be blank"], email: ["is invalid"] }
record.errors.details                      # { name: [{error: :blank}], email: [{error: :invalid}] }
record.errors.to_hash                      # Same as messages but frozen
```

## Filtering errors

```ruby
# where — returns array of ActiveModel::Error objects
record.errors.where(:name)                         # all errors on :name
record.errors.where(:name, :too_short)             # specific type
record.errors.where(:name, :too_short, minimum: 3) # with options match

# Error object properties
error = record.errors.where(:name).first
error.attribute   # :name
error.type        # :too_short
error.options     # { count: 3 }
error.message     # "is too short (minimum is 3 characters)"
error.full_message # "Name is too short (minimum is 3 characters)"
error.details     # { error: :too_short, count: 3 }
```

## Adding errors

```ruby
errors.add(:name, :blank)                                # Standard type
errors.add(:name, :too_short, count: 3)                  # With options for i18n
errors.add(:name, "must be unique within the team")      # Custom string message
errors.add(:base, "This record is invalid")              # Record-level error
errors.add(:name, :custom_type, message: "is not ok")    # Custom type + message
```

## Checking errors

```ruby
errors.added?(:name, :blank)           # Was this exact error added?
errors.added?(:name, :too_short, count: 3)  # With option match
errors.of_kind?(:name, :blank)         # Like added? but ignores options
errors.include?(:name)                 # Any errors on this attribute?

# Aliases
errors.has_key?(:name)                 # same as include?
errors.key?(:name)                     # same as include?
```

## Clearing

```ruby
errors.clear          # Remove all errors (they come back on next valid? call)
errors.delete(:name)  # Remove errors for one attribute
```

---

## I18n and Error Messages

### Error message lookup order

For `validates :name, presence: true` on `User`:

1. `activerecord.errors.models.user.attributes.name.blank`
2. `activerecord.errors.models.user.blank`
3. `activerecord.errors.messages.blank`
4. `errors.attributes.name.blank`
5. `errors.messages.blank`

### Locale file structure

```yaml
# config/locales/en.yml
en:
  activerecord:
    errors:
      models:
        user:
          attributes:
            email:
              blank: "is required"
              taken: "is already registered"
              invalid: "doesn't look right"
            name:
              too_short: "needs at least %{count} characters"
          # Model-level (any attribute):
          invalid: "has problems"
      # Global (any model):
      messages:
        blank: "cannot be empty"
  errors:
    # Fallback for ActiveModel (non-AR):
    messages:
      blank: "is required"
```

### Message interpolation variables

Available in all messages:
- `%{value}` — the attribute value
- `%{attribute}` — humanized attribute name
- `%{model}` — humanized model name

Additional for specific validators:
- `%{count}` — for length, numericality constraints

### Custom error types with i18n

```ruby
# Model:
errors.add(:discount, :too_high, count: 50)

# Locale:
# activerecord.errors.models.order.attributes.discount.too_high: "cannot exceed %{count}%"
```

### Proc messages

```ruby
validates :username, uniqueness: {
  message: ->(object, data) {
    "#{data[:value]} is taken. Try #{data[:value]}#{object.id || rand(100)}"
  }
}
```
