# Advanced Patterns

## Job Continuations

### When to Use

- Jobs processing large datasets (thousands of records)
- Multi-phase jobs (validate → process → finalize)
- Jobs that may be interrupted by deploys or queue shutdowns
- Any job where restarting from scratch is expensive

### Step-by-Step Pattern

```ruby
class DataMigrationJob < ApplicationJob
  include ActiveJob::Continuable

  def perform(migration_id)
    @migration = DataMigration.find(migration_id)

    step :validate do
      @migration.validate_schema!
    end

    step :migrate_records do |step|
      @migration.records.find_each(start: step.cursor) do |record|
        record.migrate!
        step.advance! from: record.id
      end
    end

    step :update_indexes do
      @migration.rebuild_indexes!
    end

    step :complete do
      @migration.update!(status: :completed, completed_at: Time.current)
    end
  end
end
```

### How It Works

1. Each `step` is recorded as the job progresses
2. If the job is interrupted (deploy, shutdown, crash), it's re-enqueued
3. On retry, completed steps are skipped
4. Steps with cursors (`step.advance!`) resume from the last recorded position
5. Code BEFORE the first `step` runs every time (use for setup like `@migration = ...`)

## Performance Patterns

### Batch Processing in Jobs

```ruby
class ProcessRecordsJob < ApplicationJob
  BATCH_SIZE = 1000

  def perform(start_id = 0)
    records = Record.where("id > ?", start_id).order(:id).limit(BATCH_SIZE)
    return if records.empty?

    records.each { |r| r.process! }

    # Self-enqueue for next batch
    if records.size == BATCH_SIZE
      self.class.perform_later(records.last.id)
    end
  end
end
```

### Avoid N+1 in Jobs

```ruby
class NotifyFollowersJob < ApplicationJob
  def perform(post)
    # ❌ N+1 — each follower triggers a query
    post.author.followers.each { |f| f.notify(post) }

    # ✅ Eager load
    post.author.followers.includes(:notification_preferences).find_each do |follower|
      follower.notify(post) if follower.notification_preferences.posts?
    end
  end
end
```

### Timeouts for External Calls

```ruby
class WebhookDeliveryJob < ApplicationJob
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 5
  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 5

  def perform(webhook)
    # ALWAYS set timeouts on external HTTP calls
    response = Faraday.post(webhook.url, webhook.payload.to_json) do |req|
      req.options.timeout = 10        # Read timeout
      req.options.open_timeout = 5    # Connection timeout
      req.headers["Content-Type"] = "application/json"
    end

    webhook.update!(
      last_delivered_at: Time.current,
      last_status: response.status
    )
  end
end
```

## Anti-Patterns

### 1. Fat Jobs

```ruby
# ❌ Bad — one massive job doing everything
class ProcessOrderJob < ApplicationJob
  def perform(order)
    charge_payment(order)
    send_confirmation_email(order)
    update_inventory(order)
    notify_warehouse(order)
    sync_to_crm(order)
  end
end

# ✅ Good — chain of focused jobs
class ProcessOrderJob < ApplicationJob
  def perform(order)
    PaymentService.charge(order)
    order.update!(status: :paid)

    # Enqueue downstream jobs
    SendConfirmationJob.perform_later(order)
    UpdateInventoryJob.perform_later(order)
    NotifyWarehouseJob.perform_later(order)
    CrmSyncJob.perform_later(order)
  end
end
```

### 2. Passing Complex State

```ruby
# ❌ Bad — passing computed state (not serializable, stale)
result = expensive_computation(data)
ProcessResultJob.perform_later(result)

# ✅ Good — pass identifiers, let the job compute
ProcessResultJob.perform_later(data_id)

# Or persist state and pass the record
result = ComputationResult.create!(data: data, output: expensive_computation(data))
ProcessResultJob.perform_later(result)
```

### 3. Silent Failures

```ruby
# ❌ Bad — swallows all errors
class DangerousJob < ApplicationJob
  def perform(record)
    record.process!
  rescue => e
    Rails.logger.error(e.message)
    # Error is lost. No retry. No alert.
  end
end

# ✅ Good — explicit retry/discard strategy
class SafeJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(record)
    record.process!
  end
end
```

### 4. Time-Dependent Logic Without freeze_time

```ruby
# ❌ Bad test — flaky on slow CI
test "schedules for tomorrow" do
  ReminderJob.perform_later(user)
  assert_enqueued_with(at: Date.tomorrow.noon)  # May fail if clock ticks
end

# ✅ Good test
test "schedules for tomorrow" do
  freeze_time do
    ReminderJob.perform_later(user)
    assert_enqueued_with(at: Date.tomorrow.noon)
  end
end
```

## Migration from Other Backends

### From Sidekiq

| Sidekiq | Active Job (Solid Queue) |
|---------|--------------------------|
| `include Sidekiq::Job` | `< ApplicationJob` |
| `perform_async(args)` | `perform_later(args)` |
| `perform_in(5.minutes, args)` | `set(wait: 5.minutes).perform_later(args)` |
| `sidekiq_options queue: :critical` | `queue_as :critical` |
| `sidekiq_retry_in { \|count\| count * 30 }` | `retry_on Error, wait: ->(n) { n * 30 }` |
| `Sidekiq::Cron` | `config/recurring.yml` |
| Redis | Database (SQLite/Postgres/MySQL) |
| `Sidekiq::Testing.inline!` | `perform_enqueued_jobs { }` |
| `Sidekiq::Testing.fake!` | Default test behavior (jobs enqueued, not run) |

### From Delayed Job

| Delayed Job | Active Job (Solid Queue) |
|-------------|--------------------------|
| `object.delay.method` | Create a job class explicitly |
| `handle_asynchronously :method` | `MethodJob.perform_later(object)` |
| `Delayed::Job.enqueue(job)` | `MyJob.perform_later(args)` |
| `run_at: 5.minutes.from_now` | `.set(wait: 5.minutes).perform_later` |
| `priority: 0` | `queue_with_priority 0` |
| `queue: "mailers"` | `queue_as :mailers` |
