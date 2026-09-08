# Dirty Tracking

## Manual (without Attributes)

```ruby
class Config
  include ActiveModel::Dirty

  define_attribute_methods :theme, :locale

  def theme
    @theme
  end

  def theme=(val)
    theme_will_change! unless val == @theme
    @theme = val
  end

  def locale
    @locale
  end

  def locale=(val)
    locale_will_change! unless val == @locale
    @locale = val
  end

  def save
    # persist...
    changes_applied  # Clears current changes, moves to previous_changes
  end

  def reload!
    clear_changes_information  # Clears everything
  end

  def rollback!
    restore_attributes  # Reverts to previous values
  end
end
```

## Automatic (with Attributes) — much simpler

When you use `ActiveModel::Attributes`, dirty tracking comes for free:

```ruby
class Config
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty

  attribute :theme, :string, default: "light"
  attribute :locale, :string, default: "en"
end

config = Config.new
config.changed?         # => false
config.theme = "dark"
config.changed?         # => true
config.changes          # => {"theme"=>["light", "dark"]}
config.theme_was        # => "light"
config.theme_changed?   # => true
```

## Available Query Methods

| Method | Returns |
|--------|---------|
| `changed?` | `true` if any attribute changed |
| `changed` | Array of changed attribute names |
| `changes` | Hash: `{ attr => [old, new] }` |
| `changed_attributes` | Hash: `{ attr => old_value }` |
| `previous_changes` | Changes from before last `changes_applied` |
| `[attr]_changed?` | Did this specific attribute change? |
| `[attr]_was` | Previous value |
| `[attr]_change` | `[old, new]` or `nil` |
| `[attr]_previously_changed?` | Changed before last save? |
| `[attr]_previous_change` | `[old, new]` from before last save |
