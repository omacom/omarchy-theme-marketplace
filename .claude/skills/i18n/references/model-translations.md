# Active Record Model Translations and Error Messages

## Complete Model Translation Example

```yaml
en:
  activerecord:
    models:
      user:
        one: "User"
        other: "Users"
      order:
        one: "Order"
        other: "Orders"

    attributes:
      user:
        email: "Email address"
        first_name: "First name"
        last_name: "Last name"
        role: "Role"
      order:
        total: "Total amount"
        status: "Status"
        placed_at: "Date placed"

    errors:
      models:
        user:
          attributes:
            email:
              blank: "is required"
              taken: "is already registered — did you mean to sign in?"
              invalid: "doesn't look right — check for typos"
            password:
              too_short: "must be at least %{count} characters"
        order:
          attributes:
            total:
              greater_than: "must be more than %{count}"
```

## Using ActiveModel (non-AR classes)

For classes that include `ActiveModel` but don't inherit from `ActiveRecord::Base`:

```yaml
en:
  activemodel:     # NOT activerecord
    models:
      contact_form: "Contact Form"
    attributes:
      contact_form:
        email: "Your email"
    errors:
      models:
        contact_form:
          attributes:
            email:
              blank: "is required"
```

## STI (Single Table Inheritance) Lookups

```ruby
class Admin < User; end
```

Error lookup order for `Admin` model, `name` attribute, `:blank` error:

```
activerecord.errors.models.admin.attributes.name.blank
activerecord.errors.models.admin.blank
activerecord.errors.models.user.attributes.name.blank   # ← walks up inheritance
activerecord.errors.models.user.blank
activerecord.errors.messages.blank
errors.attributes.name.blank
errors.messages.blank
```

## Nested Attributes

```yaml
en:
  activerecord:
    attributes:
      user/role:
        admin: "Administrator"
        member: "Member"
```

```ruby
User.human_attribute_name("role.admin")  # => "Administrator"
```

---

## Error Message Resolution Chain

### Full Resolution Order

For model `User`, attribute `email`, error `:blank`:

```
1. activerecord.errors.models.user.attributes.email.blank
2. activerecord.errors.models.user.blank
3. activerecord.errors.messages.blank
4. errors.attributes.email.blank
5. errors.messages.blank
```

### Available Interpolation Variables

All error messages have access to:
- `%{model}` — translated model name
- `%{attribute}` — translated attribute name
- `%{value}` — the current attribute value

Some validations also provide:
- `%{count}` — the validation option value (length, numericality thresholds)

### Full Message Format

```yaml
en:
  errors:
    # Default: "%{attribute} %{message}"
    format: "%{attribute} %{message}"

  # Per-model/attribute override (requires config):
  activerecord:
    errors:
      models:
        user:
          format: "%{attribute}: %{message}"
          attributes:
            email:
              format: "Email → %{message}"
```

Enable per-model format customization:

```ruby
# config/application.rb
config.active_model.i18n_customize_full_message = true
```

### Validation-to-Error-Key Mapping

| Validation | Option | Error Key | Extra Interpolation |
|-----------|--------|-----------|-------------------|
| `presence` | — | `:blank` | — |
| `uniqueness` | — | `:taken` | — |
| `format` | — | `:invalid` | — |
| `inclusion` | — | `:inclusion` | — |
| `exclusion` | — | `:exclusion` | — |
| `confirmation` | — | `:confirmation` | `attribute` |
| `acceptance` | — | `:accepted` | — |
| `absence` | — | `:present` | — |
| `length` | `:minimum` | `:too_short` | `count` |
| `length` | `:maximum` | `:too_long` | `count` |
| `length` | `:is` | `:wrong_length` | `count` |
| `length` | `:in` / `:within` | `:too_short` / `:too_long` | `count` |
| `numericality` | — | `:not_a_number` | — |
| `numericality` | `:only_integer` | `:not_an_integer` | — |
| `numericality` | `:greater_than` | `:greater_than` | `count` |
| `numericality` | `:greater_than_or_equal_to` | `:greater_than_or_equal_to` | `count` |
| `numericality` | `:equal_to` | `:equal_to` | `count` |
| `numericality` | `:less_than` | `:less_than` | `count` |
| `numericality` | `:less_than_or_equal_to` | `:less_than_or_equal_to` | `count` |
| `numericality` | `:other_than` | `:other_than` | `count` |
| `numericality` | `:odd` | `:odd` | — |
| `numericality` | `:even` | `:even` | — |
| `associated` | — | `:invalid` | — |
