# Parallel Testing Details

Configuration and troubleshooting for parallel test execution in Rails.

---

## Process vs Thread Comparison

| Feature | Processes (default) | Threads |
|---------|-------------------|---------|
| Isolation | Full process isolation | Shared memory |
| Database | Separate DB per worker | Shared DB (careful!) |
| Speed | Overhead from forking | Less overhead |
| Compatibility | Works with everything | Thread-safety required |
| Best for | CRuby (MRI) | JRuby, TruffleRuby |

## Common Parallel Testing Issues

**Issue: Shared file system resources**
```ruby
# BAD — workers overwrite each other
test "generates report" do
  ReportGenerator.generate(path: "/tmp/report.pdf")
  assert File.exist?("/tmp/report.pdf")
end

# GOOD — unique paths per worker
parallelize_setup do |worker|
  FileUtils.mkdir_p(Rails.root.join("tmp/test-#{worker}"))
end

test "generates report" do
  path = Rails.root.join("tmp/test-#{ENV['TEST_ENV_NUMBER']}/report.pdf")
  ReportGenerator.generate(path: path)
  assert File.exist?(path)
end
```

**Issue: External service rate limits**
```ruby
# Use VCR or WebMock to avoid hitting real services in parallel
# Or use per-worker API keys
parallelize_setup do |worker|
  ENV["API_KEY"] = "test-key-#{worker}"
end
```

## Time Testing Patterns

### Available Time Helpers

```ruby
# Freeze time at current moment
freeze_time do
  now = Time.current
  sleep 1
  assert_equal now, Time.current  # Time didn't advance
end

# Travel to specific point
travel_to DateTime.new(2024, 12, 25, 9, 0, 0) do
  assert_equal "Wednesday", Date.current.strftime("%A")
end

# Travel by duration
travel 2.days do
  assert user.trial_expired?  # If trial was 1 day
end

# Travel back (undo travel)
travel_to 1.week.ago
# ... do stuff ...
travel_back  # Return to real time
```

### Common Time Testing Patterns

```ruby
test "subscription expires after 30 days" do
  sub = Subscription.create!(started_at: Time.current)
  refute sub.expired?

  travel 29.days do
    refute sub.expired?
  end

  travel 31.days do
    assert sub.expired?
  end
end

test "scheduled job runs at correct time" do
  travel_to Time.zone.local(2024, 1, 15, 8, 59) do
    refute DailyDigestJob.should_run?
  end

  travel_to Time.zone.local(2024, 1, 15, 9, 0) do
    assert DailyDigestJob.should_run?
  end
end
```

## Common Flaky Test Patterns

### Problem: Database Race Conditions

```ruby
# FLAKY — parallel test might see different count
test "there are 5 users" do
  assert_equal 5, User.count
end

# STABLE — test relative changes
test "creating adds one user" do
  assert_difference "User.count", 1 do
    User.create!(email: "new@example.com")
  end
end
```

### Problem: Time-Dependent Logic

```ruby
# FLAKY — fails near midnight or in different timezones
test "created today" do
  article = Article.create!
  assert_equal Date.today, article.created_at.to_date
end

# STABLE — freeze time
test "created today" do
  freeze_time do
    article = Article.create!
    assert_equal Date.current, article.created_at.to_date
  end
end
```

### Problem: Random Ordering Assumptions

```ruby
# FLAKY — database doesn't guarantee order
test "first user is admin" do
  assert User.first.admin?
end

# STABLE — be explicit
test "admin fixture exists" do
  assert users(:admin).admin?
end
```

### Problem: Capybara Timing

```ruby
# FLAKY — element might not be there yet
test "shows notification" do
  click_on "Save"
  assert page.has_css?(".notification")  # Doesn't wait!

  # STABLE — use assertion that waits
  click_on "Save"
  assert_selector ".notification"  # Auto-waits
end
```

### Problem: External Services

```ruby
# FLAKY — depends on network, rate limits
test "geocodes address" do
  user = User.create!(address: "123 Main St")
  assert_not_nil user.latitude
end

# STABLE — stub external calls
test "geocodes address" do
  Geocoder::Lookup::Test.add_stub("123 Main St", [
    { "latitude" => 40.7, "longitude" => -74.0 }
  ])

  user = User.create!(address: "123 Main St")
  assert_in_delta 40.7, user.latitude, 0.01
end
```
