# Testing I18n

## Configuration for Tests

```ruby
# config/environments/test.rb
config.i18n.raise_on_missing_translations = true
```

This makes `MissingTranslationData` raise an exception instead of returning a "translation missing" span — you'll catch missing keys immediately.

For strict mode (also raises in models):

```ruby
config.i18n.raise_on_missing_translations = :strict
```

## Testing Translation Keys Exist

```ruby
# test/i18n_test.rb
require "test_helper"

class I18nTest < ActiveSupport::TestCase
  test "all locale files are valid YAML" do
    locale_files = Dir[Rails.root.join("config", "locales", "**", "*.yml")]
    locale_files.each do |file|
      assert YAML.load_file(file), "Invalid YAML: #{file}"
    end
  end

  test "all locales have the same keys" do
    en_keys = flatten_keys(I18n.backend.translations[:en])
    I18n.available_locales.reject { |l| l == :en }.each do |locale|
      locale_keys = flatten_keys(I18n.backend.translations[locale])
      missing = en_keys - locale_keys
      assert missing.empty?, "#{locale} missing keys: #{missing.join(', ')}"
    end
  end

  private

  def flatten_keys(hash, prefix = nil)
    hash.each_with_object([]) do |(k, v), keys|
      key = [prefix, k].compact.join(".")
      if v.is_a?(Hash)
        keys.concat(flatten_keys(v, key))
      else
        keys << key
      end
    end
  end
end
```

## Testing with Specific Locales

```ruby
test "shows Spanish content" do
  I18n.with_locale(:es) do
    get root_path, params: { locale: :es }
    assert_response :success
    assert_select "h1", I18n.t("home.index.title")
  end
end
```

## Testing Tip: Temporarily Force Locale

```ruby
# In test setup
setup do
  @original_locale = I18n.locale
end

teardown do
  I18n.locale = @original_locale
end

# Or better: use I18n.with_locale in each test
test "Spanish page" do
  I18n.with_locale(:es) do
    # ...
  end
end
```

---

## Common Gems

### rails-i18n

Locale data for Rails (date/time formats, pluralization rules, etc.) for 100+ languages.

```ruby
gem "rails-i18n", "~> 8.0"  # Match your Rails version
```

This gives you pre-built translations for:
- Date/time format strings
- Day/month names
- Number formatting (separators, delimiters)
- Pluralization rules
- Distance of time in words
- Active Record error messages

### i18n-tasks

Static analysis for translation keys.

```ruby
gem "i18n-tasks", group: [:development, :test]
```

```bash
# Find missing translations
bundle exec i18n-tasks missing

# Find unused translations
bundle exec i18n-tasks unused

# Normalize/sort locale files
bundle exec i18n-tasks normalize

# Check consistency
bundle exec i18n-tasks health
```

### mobility

Translate model content (database columns).

```ruby
gem "mobility"

# In model:
class Post < ApplicationRecord
  extend Mobility
  translates :title, :body, backend: :key_value
end

# Usage:
I18n.with_locale(:es) { post.title = "Título" }
```

### route_translator

Auto-translate routes.

```ruby
gem "route_translator"

# config/routes.rb
localized do
  resources :books  # /en/books, /es/libros, etc.
end
```
