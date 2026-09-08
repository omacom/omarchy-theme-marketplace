# Callback Ordering and Edge Cases

Detailed patterns for before_action, after_action, around_action, and callback classes.

## Execution order

Callbacks run in declaration order, top to bottom:

```ruby
class PostsController < ApplicationController
  before_action :first    # runs 1st
  before_action :second   # runs 2nd
  before_action :third    # runs 3rd
end
```

Inherited callbacks from parent classes run first, then the child's.

## Halting the chain

A `before_action` that calls `render` or `redirect_to` halts all remaining callbacks AND the action:

```ruby
before_action :require_admin

private
  def require_admin
    redirect_to root_path, alert: "Nope" unless current_user.admin?
    # If redirect happens, the action and remaining callbacks are skipped
  end
```

## only / except

```ruby
before_action :authenticate, except: [:index, :show]
before_action :set_record, only: [:show, :edit, :update, :destroy]
```

## skip_before_action

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate
end

class PublicController < ApplicationController
  skip_before_action :authenticate, only: [:index, :show]
end
```

`skip_before_action` raises if the callback doesn't exist. Use `raise: false` if it might not be defined:

```ruby
skip_before_action :some_callback, raise: false
```

## around_action

```ruby
around_action :wrap_in_monitoring

private
  def wrap_in_monitoring
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield  # REQUIRED — executes the action
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    Rails.logger.info "[Perf] #{controller_name}##{action_name}: #{duration.round(3)}s"
  end
```

`around_action` code after `yield` runs even if the action raises (if you use `ensure`). `after_action` does NOT run on exceptions.

## after_action

```ruby
after_action :track_response, only: [:create, :update]

private
  def track_response
    # Has access to response object
    Analytics.track(action: action_name, status: response.status)
  end
```

## Callback classes

```ruby
class AuthenticationCallback
  def self.before(controller)
    unless controller.send(:current_user)
      controller.redirect_to controller.login_path
    end
  end
end

class SecureController < ApplicationController
  before_action AuthenticationCallback
end
```

The class must implement a class method matching the callback type (`before`, `after`, `around`).

## Block callbacks

```ruby
before_action do |controller|
  redirect_to root_path unless controller.send(:current_user)&.admin?
end
```
