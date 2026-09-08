# Raw SQL — Safe Patterns

## sanitize_sql_like

```ruby
# User input in LIKE queries — escape wildcards
query = params[:search]  # Could contain % or _
safe = ActiveRecord::Base.sanitize_sql_like(query)
User.where("name LIKE ?", "#{safe}%")
```

## sanitize_sql_array / sanitize_sql_for_conditions

```ruby
# Build a parameterized SQL string
sql = ActiveRecord::Base.sanitize_sql_array(
  ["name = ? AND age > ?", "Alice", 18]
)
# => "name = 'Alice' AND age > 18"
```

## find_by_sql

```ruby
users = User.find_by_sql([
  "SELECT users.*, COUNT(posts.id) AS post_count
   FROM users
   LEFT JOIN posts ON posts.user_id = users.id
   WHERE users.active = ?
   GROUP BY users.id
   HAVING COUNT(posts.id) > ?
   ORDER BY post_count DESC
   LIMIT ?",
  true, 5, 20
])

users.first.post_count  # Accessible as virtual attribute
```

## select_all (Raw Hashes)

```ruby
result = ActiveRecord::Base.lease_connection.select_all(
  ActiveRecord::Base.sanitize_sql_array([
    "SELECT DATE(created_at) as day, COUNT(*) as total
     FROM orders
     WHERE created_at > ?
     GROUP BY day
     ORDER BY day",
    30.days.ago
  ])
)

result.to_a
# => [{"day" => "2025-01-01", "total" => 42}, ...]
```

## execute (Last Resort)

```ruby
# For DDL or statements that don't return records
ActiveRecord::Base.lease_connection.execute("VACUUM ANALYZE users")
```

## Safety Rules

```ruby
# ALWAYS use parameterized queries — never interpolate user input
User.where("email LIKE ?", "%#{User.sanitize_sql_like(query)}%")
User.where("created_at > :date", date: 1.week.ago)

# NEVER do this — SQL injection lets attackers read/modify your entire database
User.where("email = '#{params[:email]}'")  # VULNERABLE!
```
