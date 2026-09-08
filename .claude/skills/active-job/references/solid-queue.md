# Solid Queue Specifics

## Database Setup

```yaml
# config/database.yml — separate database for queue (default Rails 8 setup)
development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
    migrations_paths: db/queue_migrate

production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
```

```ruby
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

## Development Mode

By default, Rails development uses the `:async` adapter (in-process, in-memory). Jobs run but are lost on restart. To use Solid Queue in dev:

```ruby
# config/environments/development.rb
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

Then run `bin/jobs start` in a separate terminal.

## Transactional Integrity

When Solid Queue shares the app's database, jobs are enqueued inside the same transaction as your application data. This can be powerful (job only exists if data is committed) or dangerous (you depend on this behavior, then switch backends).

```ruby
# Opt in to safe behavior: enqueue AFTER transaction commits
class ApplicationJob < ActiveJob::Base
  self.enqueue_after_transaction_commit = true
end
```

## Monitoring with mission_control-jobs

```ruby
# Gemfile
gem "mission_control-jobs"

# config/routes.rb
mount MissionControl::Jobs::Engine, at: "/jobs"
```

Provides a web UI for viewing job statuses, retrying failed jobs, and queue monitoring.

## Handling Enqueue Errors

```ruby
# Solid Queue raises SolidQueue::Job::EnqueueError on DB errors during enqueue.
# This is different from ActiveJob::EnqueueError.

# Check if enqueue succeeded:
job = MyJob.perform_later(args)
if job.successfully_enqueued?
  # Job is in the queue
else
  # Enqueue failed — handle gracefully
  Rails.logger.error("Failed to enqueue #{job.class}")
end
```

## Concurrency Controls

### Basic Concurrency Limit

```ruby
class ImportJob < ApplicationJob
  # Only 1 import per account at a time
  limits_concurrency to: 1, key: ->(account) { account }, duration: 30.minutes

  def perform(account)
    account.run_import
  end
end
```

### Shared Concurrency Group

```ruby
# Two different job classes sharing a concurrency limit
class MoveContactJob < ApplicationJob
  limits_concurrency key: ->(contact) { contact },
                     duration: 15.minutes,
                     group: "ContactActions"

  def perform(contact)
    # ...
  end
end

class MergeContactJob < ApplicationJob
  limits_concurrency key: ->(contact) { contact },
                     duration: 15.minutes,
                     group: "ContactActions"

  def perform(contact)
    # Only runs when no MoveContactJob for same contact is running
  end
end
```

### How It Works

When a job with `limits_concurrency` is enqueued:
1. Solid Queue checks if the concurrency limit is reached
2. If under limit → job goes to `ready_executions` (processable)
3. If at limit → job goes to `blocked_executions` (waiting)
4. When a running job completes → Solid Queue unblocks the next waiting job
5. `duration` is a safety valve: after it expires, blocked jobs are released even if the limit wasn't freed

## Recurring Tasks

### Configuration

```yaml
# config/recurring.yml
production:
  # Simple job
  daily_cleanup:
    class: CleanupJob
    schedule: every day at 3am

  # Job with arguments
  weekly_report:
    class: WeeklyReportJob
    args: ["summary", { include_inactive: false }]
    schedule: every Monday at 9am

  # Raw command (no job class needed)
  prune_sessions:
    command: "Session.where('updated_at < ?', 30.days.ago).delete_all"
    schedule: every day at 4am

  # Frequent task
  health_ping:
    class: HealthPingJob
    schedule: every 5 minutes
```

### Schedule Syntax

Uses [Fugit](https://github.com/floraison/fugit) for parsing:

```yaml
schedule: every second
schedule: every 5 minutes
schedule: every hour
schedule: every day at 3am
schedule: every Monday at 9am
schedule: "0 3 * * *"          # Cron syntax
schedule: every 1st of month at noon
```
