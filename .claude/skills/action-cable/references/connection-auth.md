# Connection Authentication Patterns

## Devise (Cookie-Based)

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private
      def find_verified_user
        if verified_user = env["warden"].user
          verified_user
        else
          reject_unauthorized_connection
        end
      end
  end
end
```

## Session-Based (Standard Rails Auth)

```ruby
def find_verified_user
  if user_id = cookies.encrypted["_session"]["user_id"]
    User.find_by(id: user_id)
  else
    reject_unauthorized_connection
  end
end
```

## Token-Based (API/SPA)

```ruby
# Server
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private
      def find_verified_user
        token = request.params[:token]
        user = User.find_by_auth_token(token)
        user || reject_unauthorized_connection
      end
  end
end
```

```js
// Client — pass token via URL
import { createConsumer } from "@rails/actioncable"

function getWebSocketURL() {
  const token = document.querySelector('meta[name="auth-token"]')?.content
  return `/cable?token=${token}`
}

export default createConsumer(getWebSocketURL)
```

## JWT Token Auth

```ruby
def find_verified_user
  token = request.params[:token]
  payload = JWT.decode(token, Rails.application.credentials.secret_key_base).first
  User.find(payload["user_id"])
rescue JWT::DecodeError, ActiveRecord::RecordNotFound
  reject_unauthorized_connection
end
```

## Multiple Identifiers

```ruby
class Connection < ActionCable::Connection::Base
  identified_by :current_user, :current_account

  def connect
    self.current_user = find_verified_user
    self.current_account = current_user.account
  end
end
```

Both identifiers are available in all channels and can be used to target disconnections:

```ruby
ActionCable.server.remote_connections
  .where(current_user: user, current_account: account)
  .disconnect
```

## Connection Callbacks

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    before_command :set_current_attributes
    after_command :clear_current_attributes

    def connect
      self.current_user = find_verified_user
    end

    private
      def set_current_attributes
        Current.user = current_user
      end

      def clear_current_attributes
        Current.reset
      end

      def find_verified_user
        User.find_by(id: cookies.encrypted[:user_id]) ||
          reject_unauthorized_connection
      end
  end
end
```
