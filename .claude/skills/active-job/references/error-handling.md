# Error Handling Patterns

## retry_on — Full Options

```ruby
class ApiSyncJob < ApplicationJob
  # Basic — 3s wait, 5 attempts
  retry_on CustomError

  # With polynomial backoff: 3s, 18s, 83s, 258s, ...
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 10

  # Fixed wait
  retry_on RateLimitError, wait: 60.seconds, attempts: 3

  # Custom wait proc
  retry_on ApiError, wait: ->(executions) { executions * 30 }, attempts: 5

  # Move to a different queue on retry
  retry_on TransientError, queue: :retries, priority: 100

  # With jitter (default 15%, set 0 to disable)
  retry_on TimeoutError, wait: 30, jitter: 0.25  # ±25% randomness

  # Block executed after all attempts exhausted
  retry_on ExternalServiceError, attempts: 3 do |job, exception|
    AdminMailer.job_failed(job, exception).deliver_later
  end
end
```

## discard_on — When to Use

```ruby
class ProcessWebhookJob < ApplicationJob
  # Record no longer exists — nothing to process
  discard_on ActiveJob::DeserializationError

  # Bad data — retrying won't fix it
  discard_on JSON::ParserError
  discard_on ArgumentError

  # Specific business logic error
  discard_on AccountSuspendedError

  # With callback
  discard_on InvalidPayloadError do |job, error|
    Rails.logger.error("Bad webhook payload: #{error.message}")
    WebhookLog.create!(job_id: job.job_id, error: error.message, status: :discarded)
  end
end
```

## Combined Pattern — The Safety Net

```ruby
class RobustJob < ApplicationJob
  # 1. Retry transient errors
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on Redis::ConnectionError, wait: 10.seconds, attempts: 3

  # 2. Discard permanent errors
  discard_on ActiveJob::DeserializationError
  discard_on ArgumentError

  # 3. Catch-all for unexpected errors (report + re-raise for default handling)
  rescue_from Exception do |exception|
    Rails.error.report(exception)
    raise exception
  end

  def perform(record)
    # The actual work
  end
end
```

## Idempotency Guards

```ruby
class ChargeOrderJob < ApplicationJob
  def perform(order)
    # Guard: don't charge twice
    return if order.charged?

    PaymentGateway.charge(order)
    order.update!(charged_at: Time.current)
  end
end

class SendWelcomeEmailJob < ApplicationJob
  def perform(user)
    # Guard: don't send twice
    return if user.welcome_email_sent?

    UserMailer.welcome(user).deliver_now
    user.update!(welcome_email_sent_at: Time.current)
  end
end
```
