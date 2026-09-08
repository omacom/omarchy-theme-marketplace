# SQL Injection Deep Dive

## Safe vs. Unsafe ActiveRecord Methods

**Always safe (handle escaping internally):**
```ruby
User.find(id)
User.find_by(name: value)
User.where(name: value)
User.where(name: [val1, val2])
User.order(name: :asc)
User.pluck(:name, :email)
User.select(:name, :email)
```

**Safe when used correctly (with placeholders):**
```ruby
User.where("name = ?", value)
User.where("name = :name", name: value)
User.having("count(*) > ?", count)
User.joins("INNER JOIN posts ON posts.user_id = users.id")  # Safe if no interpolation
```

**Dangerous (string interpolation):**
```ruby
User.where("name = '#{value}'")         # SQL injection
User.order("#{params[:sort]}")           # SQL injection
User.select("#{params[:fields]}")        # SQL injection
User.group("#{params[:group_by]}")       # SQL injection
User.find_by_sql("SELECT * FROM users WHERE name = '#{value}'")  # SQL injection
User.pluck(Arel.sql(params[:column]))    # SQL injection
connection.execute("UPDATE users SET name = '#{value}'")  # SQL injection
```

## LIKE Query Injection

Users can inject SQL wildcards (`%` matches any string, `_` matches any char):

```ruby
# Without sanitization — user enters "%" and gets ALL records
User.where("name LIKE ?", "%#{params[:q]}%")

# With sanitization — wildcards in user input are escaped
User.where("name LIKE ?", "%#{User.sanitize_sql_like(params[:q])}%")
```

## Order Clause Injection

```ruby
# DANGEROUS — attacker can inject: "name; DROP TABLE users--"
Post.order(params[:sort])

# SAFE — permit-list approach
ALLOWED_SORT = {
  "newest" => "created_at DESC",
  "oldest" => "created_at ASC",
  "title"  => "title ASC",
  "popular" => "views_count DESC"
}.freeze

Post.order(ALLOWED_SORT.fetch(params[:sort], "created_at DESC"))
```

## Arel.sql

`Arel.sql()` tells ActiveRecord "trust this string as raw SQL." Only use with strings you fully control:

```ruby
# SAFE — literal string
Post.order(Arel.sql("COALESCE(published_at, created_at) DESC"))

# DANGEROUS — user input
Post.order(Arel.sql(params[:order_clause]))
```

## Mass Assignment Deep Dive

### Strong Parameters Patterns

```ruby
# Basic permit
def user_params
  params.require(:user).permit(:name, :email, :avatar)
end

# Array values
def post_params
  params.require(:post).permit(:title, :body, tag_ids: [])
end

# Nested attributes
def order_params
  params.require(:order).permit(
    :customer_name,
    line_items_attributes: [:id, :product_id, :quantity, :_destroy]
  )
end

# Nested hash (JSON column or serialized attribute)
def settings_params
  params.require(:user).permit(
    settings: [:theme, :locale, :notifications_enabled]
  )
end
```

### Dangerous Attributes to Never Permit from Users

```ruby
# These should NEVER appear in user-facing strong params:
# :role, :admin, :is_admin, :superadmin, :verified, :email_verified,
# :approved, :banned, :suspended, :credits, :balance,
# :password_digest (use :password and :password_confirmation instead)
# :created_at, :updated_at (set by Rails)
# :id (set by database)

# WRONG
params.require(:user).permit(:name, :email, :role, :admin)

# CORRECT — admin sets role through a separate admin-only controller
# app/controllers/admin/users_controller.rb
def user_params
  params.require(:user).permit(:name, :email, :role)  # Admin-only controller
end

# app/controllers/users_controller.rb (user-facing)
def user_params
  params.require(:user).permit(:name, :email, :bio)  # No role!
end
```

### params.permit! — The Nuclear Option

```ruby
# NEVER use this
params.permit!  # Permits EVERYTHING — defeats the entire purpose
User.create(params.permit!)  # Mass assignment on steroids

# If you think you need permit!, you're wrong. List every attribute explicitly.
```
