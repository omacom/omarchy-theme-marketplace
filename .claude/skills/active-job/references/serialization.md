# Argument Serialization Deep Dive

## Job Lifecycle

### Full Lifecycle Flow

```
1. Job.perform_later(args)
   ├── Serialize arguments (GlobalID for AR objects)
   ├── before_enqueue callbacks
   ├── around_enqueue callbacks (yield)
   ├── Enqueue to backend (Solid Queue inserts DB row)
   ├── after_enqueue callbacks
   └── Returns job instance (or false on failure)

2. Worker picks up job
   ├── Deserialize arguments (GlobalID lookup)
   ├── before_perform callbacks
   ├── around_perform callbacks (yield)
   ├── perform(deserialized_args)
   ├── after_perform callbacks
   └── Job marked complete

3. On failure
   ├── retry_on match? → Re-enqueue with wait
   ├── discard_on match? → after_discard callback → Drop
   ├── rescue_from match? → Execute handler
   └── Unhandled → Job marked failed
```

### Job States in Solid Queue

| State | DB Table | Description |
|-------|----------|-------------|
| Scheduled | `solid_queue_scheduled_executions` | Waiting for scheduled time |
| Ready | `solid_queue_ready_executions` | Available for worker pickup |
| Claimed | `solid_queue_claimed_executions` | Being processed by a worker |
| Completed | (deleted) | Successfully finished |
| Failed | `solid_queue_failed_executions` | Failed, not retried |
| Blocked | `solid_queue_blocked_executions` | Waiting for concurrency slot |

## How GlobalID Works

```ruby
# When you enqueue:
UserCleanupJob.perform_later(user)

# Active Job serializes user to:
# "gid://myapp/User/42"

# When the worker picks it up, it deserializes:
# User.find(42)
```

**Any model with `include GlobalID::Identification`** works. All ActiveRecord models include this by default.

## Supported Argument Types (Complete List)

```ruby
# All of these are safe to pass to perform_later:
SomeJob.perform_later(
  "string",                          # String
  42,                                # Integer
  3.14,                              # Float
  BigDecimal("19.99"),               # BigDecimal
  true,                              # TrueClass / FalseClass
  nil,                               # NilClass
  :my_symbol,                        # Symbol
  Date.today,                        # Date
  Time.current,                      # Time
  DateTime.now,                      # DateTime
  Time.zone.now,                     # ActiveSupport::TimeWithZone
  1.day,                             # ActiveSupport::Duration
  { key: "value" },                  # Hash (string/symbol keys)
  [1, 2, 3],                         # Array
  1..10,                             # Range
  String,                            # Class
  Enumerable,                        # Module
  ActiveSupport::HashWithIndifferentAccess.new(a: 1)
)
```

## Nested Structures

```ruby
# ✅ Safe — nested hashes and arrays with supported types
SomeJob.perform_later(
  users: [user1, user2],           # Array of AR objects
  config: { retries: 3, wait: 5 }, # Hash of primitives
  tags: ["urgent", "billing"]       # Array of strings
)

# ❌ UNSAFE — Hash with non-string/symbol keys
SomeJob.perform_later({ 1 => "one" })  # Integer key — will fail

# ❌ UNSAFE — Nested unsupported types
SomeJob.perform_later(data: OpenStruct.new(a: 1))
```

## Custom Serializer Pattern

```ruby
# app/serializers/date_range_serializer.rb
class DateRangeSerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize(range)
    super(
      "start" => range.first.iso8601,
      "end" => range.last.iso8601
    )
  end

  def deserialize(hash)
    Date.parse(hash["start"])..Date.parse(hash["end"])
  end

  def klass
    Range
  end
end

# config/initializers/active_job_serializers.rb
Rails.application.config.active_job.custom_serializers << DateRangeSerializer

# Autoload once (don't reload in dev — serializers must be stable)
# config/application.rb
config.autoload_once_paths << "#{root}/app/serializers"
```

## DeserializationError Handling

```ruby
class NotificationJob < ApplicationJob
  # Record deleted between enqueue and perform
  discard_on ActiveJob::DeserializationError

  # Or handle gracefully:
  rescue_from ActiveJob::DeserializationError do |exception|
    Rails.logger.warn("Record gone: #{exception.message}")
    # Don't re-raise — job is done
  end

  def perform(user)
    user.send_notification
  end
end
```
