# Batching — Full API

## find_each

```ruby
User.find_each { |user| process(user) }

# Options
User.find_each(batch_size: 500)       # Default: 1000
User.find_each(start: 2000)           # Start from ID 2000
User.find_each(finish: 10000)         # Stop at ID 10000
User.find_each(order: :desc)          # Reverse order (default :asc)
User.find_each(start: 2000, finish: 10000, batch_size: 500)

# With scope
User.where(active: true).find_each { |u| process(u) }

# Returns Enumerator when no block given
User.find_each.map { |u| u.email.downcase }
```

## find_in_batches

```ruby
User.find_in_batches(batch_size: 1000) do |batch|
  # batch is an Array of up to 1000 User objects
  SomeAPI.bulk_create(batch.map(&:email))
end
```

Same options as `find_each`: `batch_size`, `start`, `finish`, `order`.

## in_batches

```ruby
# Yields ActiveRecord::Relation — for bulk SQL operations
User.where(active: false).in_batches(of: 1000) do |batch_relation|
  batch_relation.update_all(archived: true)   # Single UPDATE per batch
  batch_relation.delete_all                    # Single DELETE per batch
end

# load option — also load records
User.in_batches(of: 500, load: true) do |batch_relation|
  batch_relation.records.each { |u| process(u) }
end
```

**Key constraint:** All batch methods order by primary key internally. **Custom `order()` is ignored** (or raises, depending on config).

## in_batches Improvements (Rails 8.1)

```ruby
# use_ranges option for better performance with large datasets
User.in_batches(of: 1000, use_ranges: true) do |batch|
  batch.update_all(processed: true)
end
# Uses WHERE id >= X AND id < Y instead of WHERE id IN (...)
```

## When to Use Which

| Method | Yields | Best For |
|--------|--------|----------|
| `find_each` | Individual records | Processing records one at a time |
| `find_in_batches` | Arrays of records | Bulk operations on Ruby objects |
| `in_batches` | ActiveRecord::Relation | Bulk SQL operations (update_all, delete_all) |
