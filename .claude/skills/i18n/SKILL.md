---
name: i18n
description: Expert guidance for Rails I18n (internationalization and localization). Use when working with translations, locale files, t() / l() helpers, lazy lookups, pluralization, interpolation, date/time/number formatting, model translations, error message translations, setting locale from URL/header/session, or organizing YAML translation files. Triggers on "i18n", "internationalization", "translation", "locale", "localize", "t()", "translate", "multilingual", "pluralization", "locale file", "YAML translation".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails *), Bash(bundle exec rails *)
---

# Rails I18n Expert

Internationalize and localize Rails applications using the I18n framework. Every user-facing string belongs in a locale file — never hardcode.

## Philosophy

**Core Principles:**
1. **Every string in locale files** — No hardcoded user-facing text in views, controllers, mailers, or models
2. **Lazy lookups everywhere** — Use `.title` not `books.index.title` in views/controllers
3. **Organize by feature, not language** — Split locale files by domain (models, views, defaults), not one giant file
4. **YAML is king** — Use `.yml` files unless you need Ruby lambdas for date formats
5. **Fail loud in dev/test** — Set `raise_on_missing_translations = true` so you catch missing keys early

## When To Use This Skill

- Adding I18n support to an existing Rails app
- Creating or editing YAML locale files
- Using `t()` / `I18n.t()` and `l()` / `I18n.l()` helpers
- Setting up locale switching (URL, subdomain, header, user preference)
- Translating Active Record model names, attributes, and error messages
- Localizing dates, times, numbers, and currency
- Setting up pluralization rules for non-English locales
- Organizing locale files in large applications
- Configuring fallbacks and available locales

## Instructions

### Step 1: Check Existing I18n Setup

**Inspect the project's current I18n configuration first** — mismatched conventions cause key lookup failures:

```bash
# Check existing locale files
find config/locales -name "*.yml" -o -name "*.rb" | sort

# Check I18n config
grep -r "i18n" config/application.rb config/initializers/ config/environments/

# Check available locales
grep -r "available_locales" config/

# Check for existing translation usage
rg "I18n\.t\b|\ t[\(\ ][\'\"\.]" --type ruby --type erb -l

# Check for hardcoded strings in views (potential I18n candidates)
rg -l ">[A-Z][a-z]+" app/views/ --type erb
```

Match existing conventions. If the project uses flat keys, don't introduce nested. If they organize by feature, follow that.

### Step 2: Configure I18n Properly

**Minimum viable config in `config/application.rb`:**

```ruby
# config/application.rb
config.i18n.available_locales = [:en, :es, :fr]
config.i18n.default_locale = :en
config.i18n.fallbacks = true  # Falls back to default_locale
config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
```

**In test/development — catch missing translations:**

```ruby
# config/environments/test.rb
config.i18n.raise_on_missing_translations = true

# config/environments/development.rb
config.i18n.raise_on_missing_translations = true
```

**Set `available_locales`** — without it, any locale string is accepted, which opens the door to file-system traversal attacks and unexpected fallback behavior.

### Step 3: Use Translation Helpers Correctly

#### Basic Lookups

```ruby
# In views (translate helper auto-available)
t("hello")                          # Simple key
t("messages.welcome")               # Nested key
t(:welcome, scope: :messages)       # Same thing, symbol + scope

# In controllers/models/services
I18n.t("messages.welcome")

# With default fallback
t("missing.key", default: "Fallback text")
t("missing.key", default: [:other_key, "Final fallback"])
```

#### Lazy Lookups (PREFER THESE)

Lazy lookups auto-scope based on the view path or controller action:

```yaml
# config/locales/en.yml
en:
  books:
    index:
      title: "All Books"
      empty: "No books found"
    show:
      title: "Book Details"
    create:
      success: "Book created!"
      failure: "Could not create book."
```

```erb
<%# app/views/books/index.html.erb %>
<h1><%= t(".title") %></h1>         <%# Resolves to books.index.title %>
<p><%= t(".empty") %></p>           <%# Resolves to books.index.empty %>
```

```ruby
# app/controllers/books_controller.rb
class BooksController < ApplicationController
  def create
    if @book.save
      redirect_to @book, notice: t(".success")   # books.create.success
    else
      flash.now[:alert] = t(".failure")           # books.create.failure
      render :new, status: :unprocessable_entity
    end
  end
end
```

**Prefer lazy lookups (`.key`) in views and controllers** — they keep translation keys DRY and tied to the file structure. Only use full paths when referencing shared/global keys.

#### Interpolation

```yaml
en:
  greeting: "Hello, %{name}!"
  item_count: "You have %{count} items in %{location}"
```

```ruby
t("greeting", name: current_user.name)
t("item_count", count: 5, location: "your cart")
```

Don't use `scope` or `default` as interpolation variable names — they're reserved by I18n and raise `I18n::ReservedInterpolationKey`.

#### Pluralization

```yaml
en:
  notifications:
    zero: "No notifications"      # optional for English
    one: "1 notification"
    other: "%{count} notifications"
```

```ruby
t("notifications", count: 0)   # => "No notifications"
t("notifications", count: 1)   # => "1 notification"
t("notifications", count: 42)  # => "42 notifications"
```

**The `:count` variable is magic** — it selects the plural form AND interpolates into the string.

English needs only `one` and `other`. Other languages need different forms:
- **Arabic:** `zero`, `one`, `two`, `few`, `many`, `other`
- **Russian:** `one`, `few`, `many`, `other`
- **Japanese:** `other` only

Use the `rails-i18n` gem for locale-specific pluralization rules.

#### HTML-Safe Translations

Keys ending in `_html` or named `html` are automatically marked HTML-safe in views:

```yaml
en:
  welcome_html: "<strong>Welcome</strong> to %{app_name}"
  help:
    html: "Need <em>help</em>? <a href='%{url}'>Contact us</a>"
```

```erb
<%= t("welcome_html", app_name: "MyApp") %>  <%# HTML not escaped %>
```

Interpolated values ARE still escaped (safe against XSS). Only use `_html` keys when the translation itself contains markup.

### Step 4: Translate Active Record Models

#### Model Names and Attributes

```yaml
en:
  activerecord:
    models:
      user:
        one: "User"
        other: "Users"
      admin/post: "Admin Post"    # Namespaced model
    attributes:
      user:
        email: "Email address"
        first_name: "First name"
      user/role:                   # Nested attribute
        admin: "Administrator"
```

```ruby
User.model_name.human              # => "User"
User.model_name.human(count: 2)    # => "Users"
User.human_attribute_name(:email)  # => "Email address"
```

#### Validation Error Messages

Error messages look up in this order (first match wins):

```
activerecord.errors.models.MODEL.attributes.ATTRIBUTE.ERROR
activerecord.errors.models.MODEL.ERROR
activerecord.errors.messages.ERROR
errors.attributes.ATTRIBUTE.ERROR
errors.messages.ERROR
```

```yaml
en:
  activerecord:
    errors:
      models:
        user:
          attributes:
            email:
              blank: "is required — we need this to contact you"
              taken: "is already registered"
            name:
              too_short: "must be at least %{count} characters"
          # Applies to all attributes on User:
          invalid: "has a problem"
      # Applies to all models:
      messages:
        blank: "can't be empty"

  # Global fallback for all models:
  errors:
    format: "%{attribute}: %{message}"   # Customize full_message format
    messages:
      blank: "is required"
```

Available interpolation variables in error messages: `model`, `attribute`, `value`, `count`.

### Step 5: Localize Dates, Times, and Numbers

#### Date/Time Formatting

```yaml
en:
  date:
    formats:
      default: "%Y-%m-%d"
      short: "%b %d"
      long: "%B %d, %Y"
  time:
    formats:
      default: "%a, %d %b %Y %H:%M:%S %z"
      short: "%d %b %H:%M"
      long: "%B %d, %Y %H:%M"
```

```ruby
l(Date.today)                        # Default format
l(Date.today, format: :short)        # Short format
l(Time.current, format: :long)       # Long format
```

**Use `l()` for dates/times** — `strftime` ignores the current locale, so dates won't format correctly for non-English users.

#### Number Formatting

Number helpers (`number_to_currency`, `number_with_delimiter`, etc.) read from locale files:

```yaml
en:
  number:
    format:
      separator: "."
      delimiter: ","
      precision: 3
    currency:
      format:
        unit: "$"
        format: "%u%n"           # $1,000.00
        separator: "."
        delimiter: ","
        precision: 2

es:
  number:
    currency:
      format:
        unit: "€"
        format: "%n %u"          # 1.000,00 €
        separator: ","
        delimiter: "."
```

### Step 6: Set Locale Per Request

**Use `around_action` with `I18n.with_locale`** — setting `I18n.locale =` directly leaks across requests in threaded servers (Puma), causing users to see other users' locales.

#### From URL Path (Recommended)

```ruby
# config/routes.rb
scope "(:locale)", locale: /en|es|fr/ do
  resources :books
  # ... all routes
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :switch_locale

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
```

#### Combined Priority Chain

```ruby
def resolve_locale
  params[:locale].presence ||
    current_user&.locale.presence ||
    request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first&.then { |l|
      l.to_sym if I18n.available_locales.include?(l.to_sym)
    } ||
    I18n.default_locale
end
```

### Step 7: Organize Locale Files

**Small apps:** one file per locale (`config/locales/en.yml`, `es.yml`).

**Medium/large apps** — split by concern:
```
config/locales/
  defaults/en.yml    # Date, time, number formats
  models/en.yml      # AR model names, attributes, errors
  views/en.yml       # View translations (lazy lookup keys)
  mailers/en.yml     # Mailer subjects and content
```

**Load nested directories:** `config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]`

**YAML rules:** Top-level key = locale. Keys are snake_case. Quote `'true'`/`'false'`/`'yes'`/`'no'`/`'on'`/`'off'` as keys (YAML parses them as booleans otherwise). Keep nesting ≤ 4 levels.

### Step 8: Action Mailer Translations

Mailer subjects auto-resolve from `mailer_scope.action_name.subject`:

```yaml
en:
  user_mailer:
    welcome:
      subject: "Welcome to %{app_name}!"
```

```ruby
class UserMailer < ApplicationMailer
  def welcome(user)
    mail(to: user.email)  # Subject auto-resolved
    # Or with interpolation: mail(to: user.email, subject: default_i18n_subject(app_name: "MyApp"))
  end
end
```

### Step 9: Fallbacks

```ruby
# config/application.rb
config.i18n.fallbacks = true                    # Falls back to default_locale
config.i18n.fallbacks = { es: :en, fr: :en }   # Or specific chains
```

**In development/test, keep fallbacks OFF** and `raise_on_missing_translations = true`.

## Common Agent Mistakes

1. **Hardcoding strings** — `"Record saved"` instead of `t(".success")`
2. **Wrong YAML nesting** — Forgetting locale key at top level, wrong indentation
3. **Not using lazy lookups** — `t("users.show.title")` instead of `t(".title")` in views/controllers
4. **Forgetting `available_locales`** — Without it, arbitrary locale strings are accepted (security risk)
5. **Using `I18n.locale =`** — Leaks across requests in threaded servers; use `I18n.with_locale`
6. **Pluralization without `count`** — Returns raw hash instead of string
7. **Missing `_html` suffix** — HTML in translations gets escaped without it
8. **Not quoting YAML booleans** — `true`, `false`, `yes`, `no` are parsed as booleans; quote them when used as keys
9. **Forgetting to restart server** — New locale files require restart to load

## Quick Reference

### Translation Lookup Methods

| Context | Method | Lazy Lookup |
|---------|--------|-------------|
| Views | `t(".key")` or `t("full.key")` | ✅ Yes |
| Controllers | `t(".key")` or `I18n.t("full.key")` | ✅ Yes |
| Models | `I18n.t("full.key")` | ❌ No |
| Mailers | `I18n.t("full.key")` | ❌ No |
| Services/Jobs | `I18n.t("full.key")` | ❌ No |

### Essential Locale File Structure

```yaml
en:
  # View translations (lazy lookups)
  controller_name:
    action_name:
      key: "value"
  # Shared/global
  shared:
    save: "Save"
    cancel: "Cancel"
  # Active Record
  activerecord:
    models:
      model_name: { one: "Singular", other: "Plural" }
    attributes:
      model_name:
        attribute: "Label"
    errors:
      models:
        model_name:
          attributes:
            attribute:
              error_type: "message"
  # Formats (or use rails-i18n gem)
  date:
    formats: { default: "%Y-%m-%d", short: "%b %d", long: "%B %d, %Y" }
  time:
    formats: { default: "%Y-%m-%d %H:%M" }
  number:
    currency:
      format: { unit: "$" }
  # Mailers
  mailer_name:
    action_name:
      subject: "Subject line"
```

### New Locale Checklist

- [ ] Add to `available_locales`
- [ ] Create locale files mirroring existing structure
- [ ] Add `rails-i18n` gem for date/time/number defaults + pluralization rules
- [ ] Test with `raise_on_missing_translations = true`
- [ ] Add locale switcher UI + update `default_url_options` if URL-based

For detailed patterns, examples, and edge cases, see the `references/` directory:
- `references/lookups.md` — Translation lookup methods, interpolation, lazy lookups
- `references/locale-files.md` — YAML patterns, file organization, date/time/number localization, custom backends
- `references/pluralization.md` — Pluralization rules by language
- `references/model-translations.md` — Active Record model/attribute/error translations
- `references/locale-switching.md` — Locale switching strategies and fallback configuration
- `references/testing.md` — Testing I18n, common gems (rails-i18n, i18n-tasks, mobility)
