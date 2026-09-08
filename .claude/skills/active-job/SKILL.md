---
name: active-job
description: Expert guidance for creating, queuing, and managing background jobs with Active Job and Solid Queue in Rails 8+. Use when creating background jobs, queuing work with perform_later, configuring Solid Queue, handling retries and errors (retry_on, discard_on), sending emails asynchronously (deliver_later), testing jobs, or managing queue priorities. Covers job creation, enqueuing, callbacks, serialization (GlobalID), bulk enqueuing, concurrency controls, recurring tasks, and job continuations.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails generate job:*), Bash(bin/rails generate job), Bash(bin/rails test:*), Bash(bin/rails test), Bash(bin/jobs:*)
---

# Rails Active Job Expert

Create robust, well-tested background jobs using Active Job with Solid Queue (the Rails 8 default).

## Philosophy

**Core Principles:**
1. **Solid Queue is the default** — Rails 8+ ships with Solid Queue. Use it. No Redis dependency needed.
2. **Jobs must be idempotent** — Jobs can run more than once. Design for it.
3. **Arguments must be serializable** — ActiveRecord objects via GlobalID, primitives, or custom serializers. Never pass arbitrary Ruby objects.
4. **Always handle failure** — Every job needs `retry_on` or `discard_on`. No exceptions.
5. **Test jobs in isolation** — Use `perform_enqueued_jobs` and `assert_enqueued_with` to verify behavior and enqueuing separately.

## When To Use This Skill

- Creating new background jobs
- Moving slow work out of the request cycle (emails, API calls, data processing)
- Configuring Solid Queue (queues, workers, priorities, recurring tasks)
- Handling job retries, errors, and dead letters
- Testing job behavior and enqueuing
- Integrating ActionMailer with `deliver_later`
- Setting up bulk enqueuing, concurrency controls, or job continuations

## Instructions

### Step 1: Generate the Job

```bash
bin/rails generate job process_payment
# Creates:
#   app/jobs/process_payment_job.rb
#   test/jobs/process_payment_job_test.rb
```

With a specific queue:
```bash
bin/rails generate job process_payment --queue critical
```

### Step 2: Define the Job

```ruby
class ProcessPaymentJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(order)
    # `order` is an ActiveRecord object — serialized via GlobalID automatically
    PaymentGateway.charge(order.amount, order.payment_method)
    order.update!(paid_at: Time.current)
  end
end
```

**Every job MUST have:**
- `queue_as` — explicit queue assignment
- `retry_on` and/or `discard_on` — error handling strategy
- Idempotent `perform` — safe to run multiple times

### Step 3: Enqueue the Job

```ruby
# Run as soon as a worker is free
ProcessPaymentJob.perform_later(order)

# Run at a specific time
ProcessPaymentJob.set(wait_until: Date.tomorrow.noon).perform_later(order)

# Run after a delay
ProcessPaymentJob.set(wait: 5.minutes).perform_later(order)

# Run with a specific priority (lower = higher priority)
ProcessPaymentJob.set(priority: 0).perform_later(order)

# Run synchronously (useful in console, tests, rake tasks)
ProcessPaymentJob.perform_now(order)
```

**`perform_later` vs `perform_now`:**
- `perform_later` — enqueues to background queue. Use in controllers, models, services.
- `perform_now` — runs inline, blocking. Use in console, rake tasks, tests, and other jobs that need sequential execution.

### Step 4: Handle Errors

**ALWAYS define error handling. This is non-negotiable.**

```ruby
class ExternalApiJob < ApplicationJob
  # Retry transient failures with exponential backoff
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5
  retry_on Faraday::ConnectionError, wait: 30.seconds, attempts: 3

  # Discard permanently broken jobs
  discard_on ActiveJob::DeserializationError  # Record was deleted
  discard_on ArgumentError                     # Bad arguments, retrying won't help

  # Optional: callback when a job is discarded
  after_discard do |job, exception|
    Rails.logger.warn("Discarded #{job.class.name}: #{exception.message}")
    ErrorTracker.notify(exception, job_id: job.job_id)
  end

  def perform(record)
    # ...
  end
end
```

**`retry_on` options:**
- `wait:` — seconds or `:polynomially_longer` (default: 3s)
- `attempts:` — max retries (default: 5)
- `queue:` — move to a different queue on retry
- `priority:` — change priority on retry
- `jitter:` — add randomness to wait time (default: 0.15 = 15%)

**`discard_on`** — silently drops the job. Use for unrecoverable errors.

### Step 5: Configure Queues and Priority

**Queue assignment:**
```ruby
class ImportJob < ApplicationJob
  queue_as :low_priority
end
```

**Dynamic queue based on arguments:**
```ruby
class ProcessVideoJob < ApplicationJob
  queue_as do
    video = self.arguments.first
    video.owner.premium? ? :premium : :default
  end
end
```

**Priority within a queue (lower number = higher priority):**
```ruby
class UrgentNotificationJob < ApplicationJob
  queue_as :notifications
  queue_with_priority 0  # Processed first within :notifications queue
end

class DigestNotificationJob < ApplicationJob
  queue_as :notifications
  queue_with_priority 10  # Processed after urgent ones
end
```

**Solid Queue queue ordering** in `config/queue.yml`:
```yaml
production:
  workers:
    - queues: [critical, default, low_priority]
      threads: 5
      polling_interval: 0.1
```

⚠️ **Queue order takes precedence over priority.** All jobs in `critical` process before ANY job in `default`, regardless of individual priority values. Priority only matters within a single queue.

### Step 6: Serialize Arguments Correctly

**Safe argument types (work out of the box):**
- Primitives: `String`, `Integer`, `Float`, `Boolean`, `nil`, `Symbol`
- Time types: `Date`, `Time`, `DateTime`, `ActiveSupport::TimeWithZone`, `Duration`
- Collections: `Array`, `Hash` (string/symbol keys only), `Range`
- Classes: `Module`, `Class`
- **ActiveRecord objects** — serialized via GlobalID automatically

**DANGEROUS — do NOT pass these directly:**
```ruby
# ❌ WRONG — arbitrary Ruby objects are NOT serializable
SomeJob.perform_later(Struct.new(:a).new(1))
SomeJob.perform_later(OpenStruct.new(foo: "bar"))
SomeJob.perform_later(URI.parse("https://example.com"))
SomeJob.perform_later(Money.new(100, "USD"))  # Without custom serializer

# ✅ CORRECT — pass primitives, let the job reconstruct
SomeJob.perform_later("https://example.com")
SomeJob.perform_later(100, "USD")

# ✅ CORRECT — ActiveRecord objects use GlobalID
SomeJob.perform_later(user)  # Serialized as "gid://app/User/123"
```

**Custom serializer for value objects:**
```ruby
# app/serializers/money_serializer.rb
class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize(money)
    super("amount" => money.amount, "currency" => money.currency)
  end

  def deserialize(hash)
    Money.new(hash["amount"], hash["currency"])
  end

  def klass
    Money
  end
end

# config/initializers/custom_serializers.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

### Step 7: Use Callbacks

```ruby
class AuditedJob < ApplicationJob
  before_perform :log_start
  after_perform :log_completion
  around_perform :measure_duration

  # before_enqueue / around_enqueue / after_enqueue also available
  # after_discard — fires when discard_on matches

  private

  def log_start
    Rails.logger.info("Starting #{self.class.name} #{job_id}")
  end

  def log_completion
    Rails.logger.info("Completed #{self.class.name} #{job_id}")
  end

  def measure_duration
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    StatsD.measure("jobs.#{self.class.name.underscore}.duration", elapsed)
  end
end
```

**Available callbacks:** `before_enqueue`, `around_enqueue`, `after_enqueue`, `before_perform`, `around_perform`, `after_perform`, `after_discard`

### Step 8: Test the Job

**Test job behavior (does it do the right thing?):**
```ruby
require "test_helper"

class ProcessPaymentJobTest < ActiveSupport::TestCase
  test "marks order as paid" do
    order = orders(:unpaid_order)

    perform_enqueued_jobs do
      ProcessPaymentJob.perform_later(order)
    end

    order.reload
    assert order.paid_at.present?
  end

  test "retries on timeout" do
    order = orders(:unpaid_order)

    assert_enqueued_with(job: ProcessPaymentJob) do
      ProcessPaymentJob.perform_later(order)
    end
  end
end
```

**Test that jobs get enqueued (from calling code):**
```ruby
class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "enqueues payment job on create" do
    assert_enqueued_with(job: ProcessPaymentJob) do
      post orders_path, params: { order: valid_order_params }
    end
  end

  test "enqueues to correct queue" do
    assert_enqueued_with(job: ProcessPaymentJob, queue: "critical") do
      post orders_path, params: { order: valid_order_params }
    end
  end
end
```

**Test helpers:**
```ruby
# Execute all enqueued jobs inline
perform_enqueued_jobs do
  SomeJob.perform_later(args)
end

# Execute only specific job types
perform_enqueued_jobs(only: ProcessPaymentJob) do
  # ...
end

# Assert a job was enqueued
assert_enqueued_with(job: MyJob, args: [record], queue: "default")

# Assert number of jobs enqueued
assert_enqueued_jobs 2 do
  # ...
end

# Assert no jobs enqueued
assert_no_enqueued_jobs do
  # ...
end
```

### Step 9: ActionMailer Integration

```ruby
# Send email asynchronously — enqueues via Active Job
UserMailer.welcome(@user).deliver_later

# Send with delay
UserMailer.welcome(@user).deliver_later(wait: 1.hour)

# Send immediately (bypasses queue)
UserMailer.welcome(@user).deliver_now
```

⚠️ **In Rake tasks, always use `deliver_now`** — the process may exit before `deliver_later` jobs are processed.

**Error reporting for mailer jobs:**
```ruby
class ApplicationMailer < ActionMailer::Base
  ActionMailer::MailDeliveryJob.rescue_from(Exception) do |exception|
    Rails.error.report(exception)
    raise exception
  end
end
```

### Step 10: Bulk Enqueuing

```ruby
# Create job instances (don't call perform_later individually)
jobs = users.map { |user| WelcomeEmailJob.new(user) }

# Enqueue all at once — single round-trip to the queue backend
ActiveJob.perform_all_later(jobs)

# With options
jobs = users.map { |user| WelcomeEmailJob.new(user).set(wait: 1.day) }
ActiveJob.perform_all_later(jobs)

# Mix different job classes
jobs = [
  CleanupJob.new(record),
  NotifyJob.new(user),
  ExportJob.new(data)
]
ActiveJob.perform_all_later(jobs)
```

⚠️ **`around_enqueue` callbacks are NOT triggered** during bulk enqueuing. Use `ActiveSupport::Notifications` with the `enqueue_all.active_job` event if you need to hook into bulk operations.

## Solid Queue Configuration

See `references/queues-and-priority.md` for full multi-worker queue.yml examples.

### Starting the Queue Worker

```bash
bin/jobs start  # Development — run in separate terminal
```

### Concurrency Controls

```ruby
class ImportJob < ApplicationJob
  # Only 2 imports per account at a time
  limits_concurrency to: 2, key: ->(account) { account }, duration: 5.minutes

  def perform(account)
    account.run_import
  end
end
```

### Recurring Tasks (config/recurring.yml)

```yaml
production:
  cleanup_old_records:
    class: CleanupJob
    schedule: every day at 3am
  send_daily_digest:
    class: DailyDigestJob
    args: [summary]
    schedule: every day at 9am
  health_check:
    command: "HealthCheck.run"
    schedule: every 5 minutes
```

### Job Continuations (Rails 8.1+)

For long-running jobs that may be interrupted:

```ruby
class LargeImportJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(import_id)
    @import = Import.find(import_id)

    step :validate do
      @import.validate_data!
    end

    step :process do |step|
      @import.rows.find_each(start: step.cursor) do |row|
        row.process!
        step.advance! from: row.id
      end
    end

    step :finalize do
      @import.mark_complete!
    end
  end
end
```

## Common Agent Mistakes

1. **Passing non-serializable objects** — Only primitives, ActiveRecord (via GlobalID), and registered serializer types. Everything else will raise `SerializationError`.
2. **No error handling** — Every job needs `retry_on` or `discard_on`. A job without error handling is a ticking time bomb.
3. **Not handling `DeserializationError`** — If a record is deleted between enqueue and perform, you get this error. Always `discard_on ActiveJob::DeserializationError`.
4. **Blocking jobs without timeouts** — HTTP calls, external APIs must have timeouts. Add `retry_on` for timeout errors.
5. **Non-idempotent jobs** — If the job charges money, send a guard: `return if order.paid?`. Jobs CAN run twice.
6. **Using `perform_now` in production controllers** — This blocks the request. Use `perform_later`.
7. **Forgetting queue workers in dev** — `bin/jobs start` or configure `config.active_job.queue_adapter = :async` for development.
8. **Testing with `perform_now` when you mean to test enqueuing** — Use `assert_enqueued_with` to verify the job was enqueued, `perform_enqueued_jobs` to verify behavior.

## ApplicationJob Base Class

Set up sensible defaults in `app/jobs/application_job.rb`:

```ruby
class ApplicationJob < ActiveJob::Base
  # Automatically retry transient failures
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Discard if the record no longer exists
  discard_on ActiveJob::DeserializationError

  # Report errors to your error tracker
  rescue_from(Exception) do |exception|
    Rails.error.report(exception)
    raise exception
  end

  # Wait for transaction commit before enqueuing (prevents race conditions)
  self.enqueue_after_transaction_commit = true
end
```

## Running and Debugging

```bash
# Start queue worker
bin/jobs start

# Run a job from console
ProcessPaymentJob.perform_now(Order.last)

# Check queue status (with mission_control-jobs gem)
# Visit /jobs in browser

# Enable verbose enqueue logging
# config/environments/development.rb
config.active_job.verbose_enqueue_logs = true
```


## Reference Files

See the `references/` directory for detailed patterns and edge cases:
- `references/serialization.md` — Job lifecycle, GlobalID, argument types, custom serializers
- `references/error-handling.md` — retry_on, discard_on, idempotency guards
- `references/queues-and-priority.md` — Multi-worker setup, naming, priority, ActionMailer integration
- `references/testing.md` — Enqueue assertions, job behavior, error handling, scheduled job tests
- `references/solid-queue.md` — Database setup, concurrency controls, recurring tasks, monitoring
- `references/advanced-patterns.md` — Continuations, performance, anti-patterns, migration guides
