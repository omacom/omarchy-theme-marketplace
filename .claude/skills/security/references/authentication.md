# Authentication & Authorization Patterns

For passwordless email-code auth (Basecamp, Fizzy, Herald), use the `magic-link-auth` skill instead of the password generator.

## Rails 8 Authentication Generator

```bash
bin/rails generate authentication
bin/rails db:migrate
```

This creates:
- `User` model with `has_secure_password`
- `Session` model for tracking active sessions
- `SessionsController` for login/logout
- `PasswordsController` for reset flow
- `Authentication` concern for `ApplicationController`

## Timing-Safe Authentication

```ruby
# WRONG — timing attack reveals which field is wrong
user = User.find_by(email: params[:email])
if user && user.authenticate(params[:password])
  # ...
end
# If email doesn't exist, responds faster (no bcrypt comparison)

# CORRECT — authenticate_by is timing-safe
if user = User.authenticate_by(email_address: params[:email], password: params[:password])
  # authenticate_by always performs bcrypt comparison, even if email not found
end
```

## Password Validation

```ruby
class User < ApplicationRecord
  has_secure_password

  # has_secure_password gives you:
  # - password presence on create
  # - password <= 72 bytes
  # - password_confirmation match

  # Add your own:
  validates :password, length: { minimum: 12 }, if: :password_digest_changed?
  # Consider checking against breached password databases (have_i_been_pwned gem)
end
```

## Multi-Device Session Management

```ruby
# The authentication generator creates a Session model
# Users can have multiple active sessions (one per device)

class Session < ApplicationRecord
  belongs_to :user

  # Expire old sessions
  def self.sweep(time = 30.days)
    where(updated_at: ...time.ago).delete_all
  end
end

# Logout from all devices
Current.user.sessions.delete_all
```

## Authorization Patterns

### Scoping Queries (Most Important)

```ruby
# CRITICAL — never use unscoped finds for user-owned resources
# WRONG
@project = Project.find(params[:id])

# CORRECT
@project = Current.user.projects.find(params[:id])

# For admin viewing others' resources, use policy objects
@project = authorize(Project.find(params[:id]))
```

### before_action for Access Control

```ruby
class ApplicationController < ActionController::Base
  before_action :require_authentication

  private

  def require_authentication
    redirect_to new_session_path unless authenticated?
  end
end

# Admin check
class Admin::BaseController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    head :forbidden unless Current.user&.admin?
  end
end
```

### Pundit Pattern

```ruby
class PostPolicy
  attr_reader :user, :post

  def initialize(user, post)
    @user = user
    @post = post
  end

  def update?
    post.user == user || user.admin?
  end

  def destroy?
    post.user == user || user.admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if @user.admin?
        @scope.all
      else
        @scope.where(user: @user)
      end
    end
  end
end
```
