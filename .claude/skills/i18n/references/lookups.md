# Translation Lookups and Interpolation

## Translation Lookup Deep Dive

### Lookup Methods Comparison

```ruby
# All equivalent:
I18n.t("activerecord.errors.messages.blank")
I18n.t(:blank, scope: [:activerecord, :errors, :messages])
I18n.t(:blank, scope: "activerecord.errors.messages")
I18n.translate("activerecord.errors.messages.blank")
```

### Bulk Lookup

```ruby
# Multiple keys at once
I18n.t([:odd, :even], scope: "errors.messages")
# => ["must be odd", "must be even"]

# Namespace lookup (returns hash)
I18n.t("errors.messages")
# => { blank: "can't be blank", invalid: "is invalid", ... }
```

### Deep Interpolation

```yaml
en:
  welcome:
    title: "Welcome!"
    content: "Welcome to %{app_name}, %{user}!"
```

```ruby
# Without deep_interpolation — nested values NOT interpolated
I18n.t("welcome", app_name: "MyApp", user: "Ryan")
# => { title: "Welcome!", content: "Welcome to %{app_name}, %{user}!" }

# With deep_interpolation — all values interpolated
I18n.t("welcome", deep_interpolation: true, app_name: "MyApp", user: "Ryan")
# => { title: "Welcome!", content: "Welcome to MyApp, Ryan!" }
```

### Lazy Lookup Scoping Rules

**Views** — scope is `controller_name.action_name`:

```
app/views/books/index.html.erb    → t(".key") resolves to books.index.key
app/views/books/_sidebar.html.erb → t(".key") resolves to books.sidebar.key
app/views/shared/_nav.html.erb    → t(".key") resolves to shared.nav.key
```

**Controllers** — scope is `controller_name.action_name`:

```ruby
# BooksController#create
t(".success")  # → books.create.success

# Admin::BooksController#create
t(".success")  # → admin/books.create.success
# In YAML:
# en:
#   admin/books:
#     create:
#       success: "Created!"
# OR (nested):
# en:
#   admin:
#     books:
#       create:
#         success: "Created!"
```

**Partials** — scope includes the partial name (without underscore):

```
app/views/books/_form.html.erb → t(".submit") resolves to books.form.submit
```

### Default Values

```ruby
# String default
t("missing", default: "Not found")

# Symbol default (tries another key)
t("missing", default: :fallback_key)

# Chain of defaults
t("missing", default: [:try_this, :then_this, "Final string"])

# Proc default (lazy evaluation)
t("missing", default: -> { expensive_computation })
```

### Handling Missing Translations

```ruby
# Returns nil instead of raising/showing "translation missing"
I18n.t("maybe.exists", default: nil)

# Check if translation exists
I18n.exists?("some.key")
I18n.exists?("some.key", :es)
```

---

## Interpolation Patterns

### Basic Interpolation

```yaml
en:
  greeting: "Hello, %{name}!"
  welcome: "Welcome back, %{name}. You have %{count} messages."
```

```ruby
t("greeting", name: "Ryan")
# => "Hello, Ryan!"

t("welcome", name: "Ryan", count: 5)
# => "Welcome back, Ryan. You have 5 messages."
```

### Reserved Variables

These CANNOT be used as interpolation variable names:
- `scope` → raises `I18n::ReservedInterpolationKey`
- `default` → raises `I18n::ReservedInterpolationKey`

### Missing Interpolation Arguments

```ruby
# If a required variable is not passed:
t("greeting")  # greeting expects %{name}
# => raises I18n::MissingInterpolationArgument

# To handle gracefully:
t("greeting", name: nil)  # => "Hello, !"
```

### HTML-Safe Interpolation

```yaml
en:
  # _html suffix = HTML safe
  alert_html: "<strong>Warning:</strong> %{message}"
```

```erb
<%# message is auto-escaped (XSS safe), but the translation markup is preserved %>
<%= t("alert_html", message: user_input) %>
```

The translation itself is marked `html_safe`, but interpolated values are escaped. This is secure by default.

---

## Edge Cases

### Lazy Lookup Doesn't Work Everywhere

Lazy lookup (`.key`) works in:
- ✅ Views (action templates and partials)
- ✅ Controllers (action methods)

Lazy lookup does NOT work in:
- ❌ Models
- ❌ Service objects
- ❌ Mailer bodies (works in subjects via `default_i18n_subject`)
- ❌ Jobs
- ❌ Decorators/presenters

### Pluralization Requires `:count`

```ruby
# ❌ Returns the HASH, not a string
t("notifications")
# => { one: "1 notification", other: "%{count} notifications" }

# ✅ Pass count to trigger pluralization
t("notifications", count: 5)
# => "5 notifications"
```

### HTML Safety is View-Only

The `_html` suffix auto-marks translations as `html_safe` ONLY when using the `t` view helper. In models/services, `I18n.t("key_html")` returns a plain string — you'd need to call `.html_safe` manually (be careful with XSS).

### Scope Separator is "."

Dots in translation keys require array syntax:

```yaml
en:
  "3.5_inch_floppy": "Floppy disk"  # ❌ Confusing — looks like nested key
```

```ruby
I18n.t("3.5_inch_floppy")  # Looks up key "5_inch_floppy" under "3"!

# Best: avoid dots in key names entirely
```
