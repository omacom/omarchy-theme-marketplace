# Locale Switching Strategies and Fallbacks

## Strategy 1: URL Path Scope (Most Common)

```ruby
# config/routes.rb
scope "(:locale)", locale: /en|es|fr/ do
  resources :books
  resources :users
  root "home#index"
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :switch_locale

  private

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
```

URLs: `/en/books`, `/es/books`, `/books` (uses default)

## Strategy 2: Subdomain

```ruby
def switch_locale(&action)
  locale = extract_locale_from_subdomain || I18n.default_locale
  I18n.with_locale(locale, &action)
end

def extract_locale_from_subdomain
  parsed = request.subdomains.first
  I18n.available_locales.map(&:to_s).include?(parsed) ? parsed.to_sym : nil
end
```

URLs: `en.example.com/books`, `es.example.com/books`

## Strategy 3: TLD (Top-Level Domain)

```ruby
def extract_locale_from_tld
  parsed = request.host.split(".").last
  I18n.available_locales.map(&:to_s).include?(parsed) ? parsed.to_sym : nil
end
```

URLs: `example.com/books` (en), `example.es/books` (es)

## Strategy 4: Accept-Language Header

```ruby
def extract_locale_from_header
  return nil unless request.env["HTTP_ACCEPT_LANGUAGE"]

  preferred = request.env["HTTP_ACCEPT_LANGUAGE"]
    .split(",")
    .map { |l| l.strip.split(";").first.split("-").first }
    .find { |l| I18n.available_locales.include?(l.to_sym) }

  preferred&.to_sym
end
```

## Strategy 5: User Preference (Database)

```ruby
# Migration
add_column :users, :locale, :string, default: "en", null: false

# Controller
def switch_locale(&action)
  locale = current_user&.locale&.to_sym || I18n.default_locale
  I18n.with_locale(locale, &action)
end
```

## Combined Strategy (Recommended)

```ruby
around_action :switch_locale

private

def switch_locale(&action)
  locale = resolve_locale
  I18n.with_locale(locale, &action)
end

def resolve_locale
  locale = params[:locale] ||
           current_user&.locale ||
           locale_from_header ||
           I18n.default_locale.to_s

  if I18n.available_locales.include?(locale.to_sym)
    locale.to_sym
  else
    I18n.default_locale
  end
end

def locale_from_header
  request.env["HTTP_ACCEPT_LANGUAGE"]
    &.scan(/^[a-z]{2}/)
    &.first
end
```

---

## Fallback Configuration

### Basic Fallbacks

```ruby
# config/application.rb

# All locales fall back to default_locale
config.i18n.fallbacks = true

# Specific fallback chains
config.i18n.fallbacks = {
  "es-MX": :es,      # Mexican Spanish → Spanish → default
  "pt-BR": :pt,      # Brazilian Portuguese → Portuguese → default
  fr: :en             # French → English (if default is something else)
}

# Disable fallbacks (recommended for test)
config.i18n.fallbacks = false
```

### Fallback in Initializer

```ruby
# config/initializers/locale.rb
Rails.application.config.after_initialize do
  I18n.fallbacks = I18n::Locale::Fallbacks.new(
    "es-MX": [:es, :en],
    "pt-BR": [:pt, :en]
  )
end
```

---

## Critical Safety Rule

### Thread Safety — NEVER Use `I18n.locale =`

```ruby
# ❌ DANGEROUS — leaks to other requests in threaded servers (Puma)
I18n.locale = :es
do_something
I18n.locale = I18n.default_locale

# ✅ SAFE — scoped to block
I18n.with_locale(:es) do
  do_something
end
```

### Default Locale Fallback for Missing Keys

```ruby
# With fallbacks enabled:
# config.i18n.fallbacks = true

# If es.yml has no "greeting" key, falls back to en.yml
I18n.with_locale(:es) { I18n.t("greeting") }
# => English greeting (if es translation missing)
```
