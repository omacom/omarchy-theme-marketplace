# Pluralization Rules by Language

## English (default)

```yaml
en:
  items:
    zero: "No items"     # optional
    one: "1 item"        # count == 1
    other: "%{count} items"  # everything else
```

## Russian (requires rails-i18n gem)

```yaml
ru:
  items:
    one: "%{count} элемент"      # 1, 21, 31...
    few: "%{count} элемента"     # 2-4, 22-24...
    many: "%{count} элементов"   # 5-20, 25-30...
    other: "%{count} элемента"   # 1.5, 2.5...
```

## Arabic

```yaml
ar:
  items:
    zero: "لا عناصر"
    one: "عنصر واحد"
    two: "عنصران"
    few: "%{count} عناصر"
    many: "%{count} عنصراً"
    other: "%{count} عنصر"
```

## Japanese / Chinese / Korean (no plural forms)

```yaml
ja:
  items:
    other: "%{count}個のアイテム"
```

## Enabling Locale-Specific Pluralization

```ruby
# Gemfile
gem "rails-i18n"  # Includes pluralization rules for 100+ locales

# Or manually:
# config/initializers/pluralization.rb
I18n::Backend::Simple.include(I18n::Backend::Pluralization)
```

## Pluralization Requires `:count`

```ruby
# ❌ Returns the HASH, not a string
t("notifications")
# => { one: "1 notification", other: "%{count} notifications" }

# ✅ Pass count to trigger pluralization
t("notifications", count: 5)
# => "5 notifications"
```

The `:count` variable is magic — it selects the plural form AND interpolates into the string.

English needs only `one` and `other`. Other languages need different forms:
- **Arabic:** `zero`, `one`, `two`, `few`, `many`, `other`
- **Russian:** `one`, `few`, `many`, `other`
- **Japanese:** `other` only

Use the `rails-i18n` gem for locale-specific pluralization rules.
