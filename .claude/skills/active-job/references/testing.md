# Testing Patterns

## Test Helper Configuration

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  # Jobs are NOT performed by default in tests.
  # Use perform_enqueued_jobs when you need them to run.
end
```

## Pattern 1: Test That a Job Is Enqueued

```ruby
class OrderServiceTest < ActiveSupport::TestCase
  test "placing order enqueues payment job" do
    order = orders(:pending)

    assert_enqueued_with(job: ProcessPaymentJob, args: [order]) do
      OrderService.place(order)
    end
  end

  test "placing order enqueues to critical queue" do
    order = orders(:pending)

    assert_enqueued_with(job: ProcessPaymentJob, queue: "critical") do
      OrderService.place(order)
    end
  end

  test "bulk import enqueues jobs for each row" do
    assert_enqueued_jobs 3, only: ImportRowJob do
      ImportService.process(rows: 3)
    end
  end

  test "no job enqueued for invalid order" do
    assert_no_enqueued_jobs only: ProcessPaymentJob do
      OrderService.place(orders(:invalid))
    end
  end
end
```

## Pattern 2: Test Job Behavior

```ruby
class ProcessPaymentJobTest < ActiveSupport::TestCase
  test "charges the order and marks paid" do
    order = orders(:unpaid)

    perform_enqueued_jobs do
      ProcessPaymentJob.perform_later(order)
    end

    order.reload
    assert order.paid?
    assert_not_nil order.paid_at
  end

  test "is idempotent — safe to run twice" do
    order = orders(:unpaid)

    2.times { ProcessPaymentJob.perform_now(order.reload) }

    assert_equal 1, PaymentLog.where(order: order).count
  end
end
```

## Pattern 3: Test Error Handling

```ruby
class ExternalApiJobTest < ActiveSupport::TestCase
  test "retries on timeout" do
    # Mock the API to raise timeout
    ExternalApi.stub(:call, -> { raise Net::OpenTimeout }) do
      assert_enqueued_jobs 1, only: ExternalApiJob do
        ExternalApiJob.perform_now(records(:example))
      end
    end
  end

  test "discards on deserialization error" do
    job = ExternalApiJob.new("gid://app/User/999999")

    assert_nothing_raised do
      job.perform_now
    end
  end
end
```

## Pattern 4: Test Scheduled Jobs

```ruby
class ReminderJobTest < ActiveSupport::TestCase
  test "enqueues for tomorrow" do
    freeze_time do
      assert_enqueued_with(
        job: ReminderJob,
        at: 1.day.from_now
      ) do
        ReminderService.schedule(users(:active))
      end
    end
  end
end
```

## Pattern 5: Test Mailer Jobs

```ruby
class OrderMailerTest < ActiveSupport::TestCase
  test "confirmation email is enqueued" do
    order = orders(:completed)

    assert_enqueued_emails 1 do
      OrderMailer.confirmation(order).deliver_later
    end
  end

  test "confirmation email content" do
    order = orders(:completed)

    email = OrderMailer.confirmation(order)
    assert_equal ["customer@example.com"], email.to
    assert_match "Order ##{order.number}", email.subject
  end
end
```

## Pattern 6: Test with perform_enqueued_jobs Filtering

```ruby
class ComplexWorkflowTest < ActiveSupport::TestCase
  test "only processes payment jobs, not notification jobs" do
    order = orders(:pending)

    # Only perform payment jobs; notification jobs stay enqueued
    perform_enqueued_jobs(only: ProcessPaymentJob) do
      OrderWorkflow.execute(order)
    end

    order.reload
    assert order.paid?

    # Notification job was enqueued but not yet performed
    assert_enqueued_with(job: NotifyCustomerJob)
  end
end
```
