# Locale Files — YAML Patterns, Organization, and Backends

## YAML Locale File Patterns

### Basic Structure

```yaml
# ALWAYS start with the locale key
en:
  key: "value"
  nested:
    key: "nested value"
```

### Quoting Rules — CRITICAL

YAML treats certain values as booleans/nulls. You MUST quote these when used as keys:

```yaml
en:
  # BROKEN — YAML interprets these as booleans/null
  statuses:
    true: "Active"       # ❌ parsed as boolean true
    false: "Inactive"    # ❌ parsed as boolean false
    yes: "Confirmed"     # ❌ parsed as boolean true
    no: "Denied"         # ❌ parsed as boolean false
    on: "Enabled"        # ❌ parsed as boolean true
    off: "Disabled"      # ❌ parsed as boolean false
    null: "None"         # ❌ parsed as null

  # CORRECT — quote the keys
  statuses:
    'true': "Active"
    'false': "Inactive"
    'yes': "Confirmed"
    'no': "Denied"
    'on': "Enabled"
    'off': "Disabled"
    'null': "None"
```

### Multi-line Strings

```yaml
en:
  # Literal block (preserves newlines)
  terms: |
    By using this service, you agree to our terms.
    Please read carefully before proceeding.

  # Folded block (joins lines with spaces)
  description: >
    This is a long description that will be
    joined into a single line with spaces.

  # Quoted with explicit newlines
  message: "Line one\nLine two"
```

### ERB in YAML (Avoid Unless Necessary)

If you must use dynamic values, name the file `.yml.erb`:

```yaml
# config/locales/en.yml — NOT .yml.erb, this won't work
en:
  app_name: "MyApp"

# Only use .yml.erb if truly needed (rare):
en:
  build: "<%= ENV['BUILD_VERSION'] %>"
```

### File Organization for Large Apps

```
config/locales/
├── en.yml                    # Simple/shared keys
├── es.yml
├── models/
│   ├── en.yml                # activerecord.models, .attributes, .errors
│   └── es.yml
├── views/
│   ├── books/
│   │   ├── en.yml            # books.index.*, books.show.*, etc.
│   │   └── es.yml
│   └── users/
│       ├── en.yml
│       └── es.yml
├── mailers/
│   ├── en.yml
│   └── es.yml
└── defaults/
    ├── en.yml                # date.formats, time.formats, number.*
    └── es.yml
```

**Loading nested files:**

```ruby
# config/application.rb
config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
```

---

## Date, Time, and Number Localization

### Full Date/Time Locale File

```yaml
en:
  date:
    abbr_day_names:
      - Sun
      - Mon
      - Tue
      - Wed
      - Thu
      - Fri
      - Sat
    abbr_month_names:
      -            # index 0 is nil
      - Jan
      - Feb
      - Mar
      - Apr
      - May
      - Jun
      - Jul
      - Aug
      - Sep
      - Oct
      - Nov
      - Dec
    day_names:
      - Sunday
      - Monday
      - Tuesday
      - Wednesday
      - Thursday
      - Friday
      - Saturday
    formats:
      default: "%Y-%m-%d"
      long: "%B %d, %Y"
      short: "%b %d"
    month_names:
      -            # index 0 is nil
      - January
      - February
      - March
      - April
      - May
      - June
      - July
      - August
      - September
      - October
      - November
      - December
    order:
      - :year
      - :month
      - :day

  time:
    am: "am"
    pm: "pm"
    formats:
      default: "%a, %d %b %Y %H:%M:%S %z"
      long: "%B %d, %Y %H:%M"
      short: "%d %b %H:%M"
      time_only: "%H:%M"

  number:
    format:
      separator: "."
      delimiter: ","
      precision: 3
      significant: false
      strip_insignificant_zeros: false
    currency:
      format:
        format: "%u%n"
        unit: "$"
        separator: "."
        delimiter: ","
        precision: 2
    percentage:
      format:
        delimiter: ""
        format: "%n%"
    precision:
      format:
        delimiter: ""
    human:
      format:
        delimiter: ""
        precision: 3
      storage_units:
        format: "%n %u"
        units:
          byte:
            one: "Byte"
            other: "Bytes"
          kb: "KB"
          mb: "MB"
          gb: "GB"
          tb: "TB"
          pb: "PB"
          eb: "EB"
```

### Usage Examples

```ruby
# Dates
l(Date.today)                         # => "2026-03-06"
l(Date.today, format: :long)          # => "March 06, 2026"
l(Date.today, format: :short)         # => "Mar 06"

# Times
l(Time.current)                       # Default format
l(Time.current, format: :short)       # Short format

# Custom format on the fly
l(Time.current, format: "%B %Y")      # => "March 2026"

# Numbers
number_to_currency(1234.50)           # => "$1,234.50"
number_with_delimiter(1234567)        # => "1,234,567"
number_to_percentage(75.5)            # => "75.500%"
number_to_human_size(1234567)         # => "1.18 MB"
```

### Spanish Example

```yaml
es:
  date:
    formats:
      default: "%d/%m/%Y"
      long: "%d de %B de %Y"
      short: "%d %b"
    day_names:
      - domingo
      - lunes
      - martes
      - miércoles
      - jueves
      - viernes
      - sábado
    month_names:
      -
      - enero
      - febrero
      - marzo
      - abril
      - mayo
      - junio
      - julio
      - agosto
      - septiembre
      - octubre
      - noviembre
      - diciembre
  number:
    format:
      separator: ","
      delimiter: "."
    currency:
      format:
        unit: "€"
        format: "%n %u"
        separator: ","
        delimiter: "."
```

---

## Localized Views

Rails supports locale-specific view templates:

```
app/views/books/
  index.html.erb       # Default (any locale)
  index.es.html.erb    # Spanish-specific
  index.ja.html.erb    # Japanese-specific
```

When `I18n.locale = :es`, Rails renders `index.es.html.erb`. Falls back to `index.html.erb` if locale-specific template doesn't exist.

**Use sparingly.** Localized views are useful for:
- Significantly different layouts per locale (RTL vs LTR)
- Large blocks of static content
- Legal pages that differ by region

For most cases, YAML translations with `t()` are more maintainable.

---

## Custom Backends

### Chain Backend (Most Common)

Combine multiple backends — look up in order, first match wins:

```ruby
# config/initializers/i18n.rb
I18n.backend = I18n::Backend::Chain.new(
  I18n::Backend::ActiveRecord.new,  # Check DB first
  I18n.backend                       # Fall back to YAML files
)
```

### Key-Value Backend

Store translations in Redis, database, etc.:

```ruby
# Using i18n-active_record gem
gem "i18n-active_record"

# config/initializers/i18n.rb
I18n.backend = I18n::Backend::Chain.new(
  I18n::Backend::ActiveRecord.new,
  I18n::Backend::Simple.new
)
```

### Cache Backend

Wrap any backend with caching:

```ruby
I18n::Backend::Simple.include(I18n::Backend::Cache)
I18n.cache_store = ActiveSupport::Cache.lookup_store(:memory_store)
```

---

## Edge Cases

### New Locale Files Require Server Restart

Locale files are loaded at boot. Adding a new `.yml` file requires restarting the server. Editing an existing file works with Spring/reloader in development.

### YAML Indentation Matters

```yaml
# ❌ Wrong indentation — "name" is NOT under "attributes"
en:
  activerecord:
    attributes:
    user:
      name: "Name"

# ✅ Correct
en:
  activerecord:
    attributes:
      user:
        name: "Name"
```

### Locale Files Merge, Not Replace

Multiple YAML files for the same locale are deep-merged. This means you can split translations across files:

```yaml
# config/locales/models/en.yml
en:
  activerecord:
    models:
      user: "User"

# config/locales/views/en.yml
en:
  users:
    index:
      title: "All Users"
```

Both are available. If the same key exists in multiple files, the last-loaded file wins (load order depends on file system + load_path order).

### Percent Signs in YAML

```yaml
en:
  # Only "%{variable_name}" triggers interpolation
  # Literal "%" followed by anything except "{" is safe
  discount: "50% off"  # This is fine
```
