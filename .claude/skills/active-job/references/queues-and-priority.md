# Queue Configuration Patterns

## Multi-Worker Setup

```yaml
# config/queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500

  workers:
    # High-priority worker: fast jobs only
    - queues: [critical, mailers]
      threads: 5
      processes: 2
      polling_interval: 0.1

    # Default worker: general purpose
    - queues: [default]
      threads: 3
      processes: 2
      polling_interval: 0.5

    # Background worker: slow/heavy jobs
    - queues: [low_priority, imports, exports]
      threads: 2
      processes: 1
      polling_interval: 2
```

## Queue Naming Conventions

```ruby
# Good — descriptive, hierarchical
queue_as :critical        # Payment processing, auth
queue_as :default         # Standard business logic
queue_as :mailers         # Email delivery
queue_as :notifications   # Push notifications, in-app
queue_as :imports         # Data imports (potentially slow)
queue_as :exports         # Report generation
queue_as :low_priority    # Cleanup, analytics, non-urgent

# Bad — too generic or duplicative
queue_as :queue1
queue_as :jobs
queue_as :background      # Everything is background
```

## Queue Name Prefixing

```ruby
# config/application.rb
config.active_job.queue_name_prefix = Rails.env
# Result: production_default, staging_default, etc.

# Override per-job if needed
class SharedJob < ApplicationJob
  self.queue_name_prefix = nil  # No prefix
  queue_as :shared
end
```

## Priority Within Queues

```ruby
# Priority is a positive integer. Lower = more important.
class CriticalAlertJob < ApplicationJob
  queue_as :notifications
  queue_with_priority 0    # Process first
end

class WeeklyDigestJob < ApplicationJob
  queue_as :notifications
  queue_with_priority 50   # Process after critical
end

# Dynamic priority
class ProcessOrderJob < ApplicationJob
  queue_with_priority do
    order = arguments.first
    order.express? ? 0 : 10
  end
end
```

## ActionMailer Integration

### Basic Usage

```ruby
# Async (default in production) — uses Active Job
UserMailer.welcome(user).deliver_later

# With delay
UserMailer.welcome(user).deliver_later(wait: 1.hour)
UserMailer.welcome(user).deliver_later(wait_until: user.created_at + 1.day)

# Specific queue
UserMailer.welcome(user).deliver_later(queue: :mailers)

# Synchronous — bypasses Active Job entirely
UserMailer.welcome(user).deliver_now
```

### Locale Preservation

```ruby
# Active Job preserves I18n.locale from enqueue time
I18n.locale = :fr
UserMailer.welcome(user).deliver_later
# Email will be generated in French, even if worker locale is :en
```

### Error Handling for Mailer Jobs

```ruby
# Mailer jobs use ActionMailer::MailDeliveryJob, NOT ApplicationJob.
# So rescue_from in ApplicationJob won't catch mailer errors.

class ApplicationMailer < ActionMailer::Base
  ActionMailer::MailDeliveryJob.rescue_from(Exception) do |exception|
    Rails.error.report(exception)
    raise exception
  end
end
```
