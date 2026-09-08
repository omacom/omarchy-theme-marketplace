---
name: testing
description: Expert guidance for Rails testing infrastructure, test types, and what to test. Use when writing tests, setting up a test suite, choosing between test types, configuring system tests (Capybara), request tests, integration tests, helper tests, mailer tests, job tests, Action Cable tests, parallel testing, CI setup, test database management, or improving test coverage. Covers the test runner, fixtures vs factories, parallel testing, system tests (drivers, screenshots), request tests, controller tests (legacy), helper tests, mailer tests, job tests, Action Cable tests, test coverage, CI patterns, and test database strategies. Trigger on "test", "testing", "test suite", "system test", "request test", "integration test", "test runner", "parallel testing", "capybara", "test database", "CI testing", "test coverage".
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bin/rails test:*), Bash(bin/rails test), Bash(bundle exec rails test:*)
---

# Rails Testing Expert

Build fast, reliable, maintainable test suites for Rails applications. This skill covers the Rails testing ecosystem — test types, infrastructure, and what to test where.

> **Companion skill:** For Minitest-specific assertions, fixtures deep-dive, TDD workflow, and RSpec-to-Minitest conversion, see the **minitest** skill.

## When To Use This Skill

- Setting up or configuring a Rails test suite
- Choosing between test types (system, request, model, job, mailer, etc.)
- Writing system tests with Capybara
- Configuring parallel testing or CI pipelines
- Debugging flaky tests or test database issues
- Adding test coverage for new features

## Philosophy

### The Testing Pyramid — Enforce It

```
      /\       System Tests (FEW — critical user paths only)
     /  \
    /____\     Request/Integration Tests (MODERATE)
   /      \
  /________\   Unit Tests (MANY — models, services, policies, jobs)
```

**Most agent mistakes come from inverting this pyramid.** Writing system tests for everything is the #1 mistake. System tests are 10-100x slower than unit tests. A single flaky system test wastes more time than 50 model tests.

### Core Rules

1. **Test behavior, not implementation** — assert outcomes, not method calls
2. **Use fixtures, not factories** — 10-100x faster, no cascade creation
3. **Prefer request tests over system tests** — only use system tests for JS-dependent flows
4. **Each test is independent** — no shared state, no test ordering dependencies
5. **Fast feedback > comprehensive coverage** — a fast suite that runs often beats a slow suite that doesn't

## Choosing the Right Test Type

This is the most important decision. Get this wrong and you waste time writing slow, brittle tests.

| Test Type | Base Class | Speed | Use For |
|-----------|-----------|-------|---------|
| **Model** | `ActiveSupport::TestCase` | ⚡ Fast | Validations, scopes, business logic, callbacks |
| **Service/PORO** | `ActiveSupport::TestCase` | ⚡ Fast | Service objects, form objects, query objects |
| **Job** | `ActiveJob::TestCase` | ⚡ Fast | Job behavior, enqueuing, retries |
| **Mailer** | `ActionMailer::TestCase` | ⚡ Fast | Email content, recipients, attachments |
| **Helper** | `ActionView::TestCase` | ⚡ Fast | View helper output |
| **Request** | `ActionDispatch::IntegrationTest` | 🔶 Medium | HTTP request/response cycle, API endpoints |
| **Integration** | `ActionDispatch::IntegrationTest` | 🔶 Medium | Multi-step workflows without a browser |
| **Channel** | `ActionCable::Channel::TestCase` | ⚡ Fast | Channel subscriptions, streams |
| **Connection** | `ActionCable::Connection::TestCase` | ⚡ Fast | WebSocket auth, connection identifiers |
| **System** | `ActionDispatch::SystemTestCase` | 🐌 Slow | JS interactions, critical E2E user paths |

### Decision Tree

```
Does it test business logic with no HTTP needed?
  → Model / Service test

Does it test an HTTP endpoint's response?
  → Request test

Does it require a real browser (JS, complex UI)?
  → System test (keep these minimal)

Does it test email content or delivery?
  → Mailer test

Does it test a background job?
  → Job test

Does it test a view helper method?
  → Helper test

Does it test a WebSocket channel?
  → Channel test
```

## Test Directory Structure

```
test/
├── test_helper.rb                    # Global config
├── application_system_test_case.rb   # System test base (created on first system test)
├── controllers/                      # Controller/functional tests (legacy — prefer request tests)
├── fixtures/                         # YAML fixture data
│   ├── users.yml
│   ├── files/                        # File fixtures for uploads
│   └── action_text/rich_texts.yml    # Action Text fixtures
├── helpers/                          # View helper tests
├── integration/                      # Integration tests
├── jobs/                             # Job tests
├── mailers/                          # Mailer tests
│   └── previews/                     # Mailer previews (not tests, but useful)
├── models/                           # Model tests (bulk of your tests)
├── channels/                         # Action Cable channel tests
│   └── application_cable/            # Connection tests
├── requests/                         # Request tests (preferred over controllers/)
├── services/                         # Service object tests
├── system/                           # System tests (keep small)
└── support/                          # Shared test helpers
```

## The Test Runner

### Essential Commands

```bash
# Run everything (excludes system tests)
bin/rails test

# Run system tests separately
bin/rails test:system

# Run ALL tests including system
bin/rails test:all

# Run a single file
bin/rails test test/models/user_test.rb

# Run a specific test by line number
bin/rails test test/models/user_test.rb:42

# Run a line range
bin/rails test test/models/user_test.rb:10-30

# Run by name pattern
bin/rails test -n /password/

# Run a directory
bin/rails test test/models/

# Fail fast — stop on first failure
bin/rails test --fail-fast

# Verbose output
bin/rails test -v

# Profile slow tests
bin/rails test --profile

# Set seed for reproducibility
bin/rails test --seed 12345
```

### Key flags

| Flag | Purpose |
|------|---------|
| `-n PATTERN` | Filter tests by name (string or `/regex/`) |
| `-f` / `--fail-fast` | Stop on first failure |
| `-v` / `--verbose` | Show each test name |
| `-b` / `--backtrace` | Full backtrace (not just app lines) |
| `--profile [N]` | List N slowest tests (default 10) |
| `-p` / `--pride` | Rainbow output 🌈 |
| `-S` / `--skip CODES` | Skip reporting types (e.g., `E` for errors) |

## Request Tests (Preferred for HTTP Testing)

Request tests simulate full HTTP requests through the middleware stack. **Use these instead of controller tests for new code.**

```ruby
class ArticlesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @article = articles(:published)
  end

  test "GET /articles returns success" do
    get articles_url
    assert_response :success
  end

  test "POST /articles creates with valid params" do
    sign_in @user
    assert_difference "Article.count", 1 do
      post articles_url, params: { article: { title: "New", body: "Content" } }
    end
    assert_redirected_to article_url(Article.last)
  end

  test "POST /articles rejects invalid params" do
    sign_in @user
    assert_no_difference "Article.count" do
      post articles_url, params: { article: { title: "" } }
    end
    assert_response :unprocessable_entity
  end
end
```

### Available After a Request

- `response` / `response.body` / `response.parsed_body`
- `cookies`, `flash`, `session`
- `@controller`, `@request`, `@response`

> **See `references/request-tests.md`** for JSON API tests, Turbo Stream tests, file uploads, auth patterns, and DOM assertions.

## System Tests (Use Sparingly)

System tests run in a real browser via Capybara. **Reserve for critical paths that require JavaScript or complex UI interaction.**

### When to Write a System Test

✅ User registration/login flow
✅ Checkout/payment flow
✅ Complex JS interactions (drag-and-drop, modals, live search)
✅ Turbo/Stimulus-dependent features
✅ File upload with preview

### When NOT to Write a System Test

❌ CRUD operations (use request tests)
❌ Validation error display (use request tests + `assert_select`)
❌ API endpoints (use request tests)
❌ Anything testable without a browser

### Configuration

```ruby
# test/application_system_test_case.rb
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome
end
```

**Driver options:**

| Driver | Browser | Use Case |
|--------|---------|----------|
| `:selenium` + `:headless_chrome` | Chrome (headless) | Default, CI-friendly |
| `:selenium` + `:headless_firefox` | Firefox (headless) | Alternative |
| `:selenium` + `:chrome` | Chrome (visible) | Debugging |
| `:cuprite` | Chrome via CDP | Faster, no Selenium overhead |

### Writing System Tests

```ruby
require "application_system_test_case"

class CheckoutTest < ApplicationSystemTestCase
  test "user completes checkout" do
    user = users(:buyer)
    product = products(:widget)

    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_on "Sign in"

    visit product_path(product)
    click_on "Add to Cart"
    click_on "Checkout"

    fill_in "Card number", with: "4242424242424242"
    click_on "Pay"

    assert_text "Order confirmed"
  end
end
```

### Avoiding Flaky System Tests

- `assert_text`, `assert_selector` auto-wait — use them instead of `page.has_css?`
- If still flaky, add explicit wait: `assert_text "Done", wait: 5`
- Never use `sleep` — always use Capybara's wait-aware assertions
- `take_screenshot` for debugging; failed tests auto-capture to `tmp/screenshots/`

> **See `references/system-tests.md`** for Capybara DSL reference, Cuprite setup, JS interaction patterns, and Turbo/Stimulus testing.

## Mailer Tests

```ruby
class UserMailerTest < ActionMailer::TestCase
  test "welcome email" do
    email = UserMailer.welcome(users(:new_user))
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal ["noreply@example.com"], email.from
    assert_equal [users(:new_user).email], email.to
    assert_equal "Welcome!", email.subject
    assert_match users(:new_user).name, email.body.to_s
  end
end
```

**From request tests:** `assert_emails 1 { post users_url, params: {...} }`
**Enqueued:** `assert_enqueued_email_with UserMailer, :welcome, args: [user] { ... }`

> **See `references/helpers-and-assertions.md`** for multipart emails, attachments, parameterized mailers, and previews.

## Job Tests

```ruby
class ProcessOrderJobTest < ActiveJob::TestCase
  test "charges the account" do
    perform_enqueued_jobs do
      ProcessOrderJob.perform_later(orders(:pending))
    end
    assert orders(:pending).reload.charged?
  end
end
```

**Verify enqueuing from other code:**
```ruby
class OrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "#place enqueues processing job" do
    assert_enqueued_with(job: ProcessOrderJob) do
      orders(:new).place!
    end
  end
end
```

> **See `references/helpers-and-assertions.md`** for job queue assertions, filtering, chained jobs, and exception testing.

## Helper Tests

```ruby
class CurrencyHelperTest < ActionView::TestCase
  test "formats USD" do
    assert_equal "$10.00", format_price(1000, "USD")
  end

  test "handles zero" do
    assert_equal "$0.00", format_price(0, "USD")
  end
end
```

## Action Cable Tests

```ruby
# Channel test
class ChatChannelTest < ActionCable::Channel::TestCase
  test "subscribes to room stream" do
    subscribe room: "general"
    assert subscription.confirmed?
    assert_has_stream "chat_general"
  end
end

# Connection test
class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with valid user" do
    cookies.signed[:user_id] = users(:admin).id
    connect
    assert_equal users(:admin).id, connection.current_user.id
  end

  test "rejects without auth" do
    assert_reject_connection { connect }
  end
end
```

**Broadcast assertions (usable in any test):** `include ActionCable::TestHelper` then use `assert_broadcast_on`, `assert_broadcasts`.

> **See `references/helpers-and-assertions.md`** for stream assertions, custom channel methods, and broadcast testing from models.

## Test Database Management

### Schema Sync

```bash
# After migrations, sync test DB schema
bin/rails db:test:prepare

# Or recreate from scratch
bin/rails db:test:purge db:test:prepare

# Rails auto-checks for pending migrations before tests run
```

### Transactions

By default, each test runs in a database transaction that rolls back after completion. This keeps tests isolated without manual cleanup.

**Disable when needed** (e.g., testing multi-threaded code):
```ruby
class ThreadedTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    # Manual cleanup needed!
    User.delete_all
  end
end
```

## Parallel Testing

### Process-Based (Default)

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
end
```

Creates separate test databases (`test-database-0`, `test-database-1`, etc.) per worker.

```bash
# Override worker count
PARALLEL_WORKERS=4 bin/rails test
```

### Thread-Based

```ruby
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors, with: :threads)
end
```

Use for JRuby/TruffleRuby, or when process forking is expensive.

Use `parallelize_setup`/`parallelize_teardown` hooks for per-worker setup. Default threshold is 50 tests (won't parallelize below that). Customize with `config.active_support.test_parallelization_threshold = 100`.

> **See `references/parallel-testing.md`** for process vs thread comparison, hooks, and common parallel testing issues.

## CI Configuration

```ruby
# config/environments/test.rb
config.eager_load = ENV["CI"].present?
```

```bash
# CI steps
bin/rails db:test:prepare
bin/rails test                    # Unit + request tests
bin/rails test:system             # System tests (separate job recommended)
```

**CI tips:** Parallelize with `PARALLEL_WORKERS`, separate system tests into their own CI job, cache gems/node_modules, use headless Chrome, add a Zeitwerk eager-load test.

> **See `references/ci.md`** for full GitHub Actions YAML and CI patterns.

## Time-Dependent Tests

```ruby
freeze_time do ... end                                    # Freeze at current moment
travel_to Time.zone.local(2024, 1, 15) do ... end        # Travel to specific time
travel 3.days do ... end                                  # Travel forward
travel_back                                               # Return to real time
```

> **See `references/parallel-testing.md`** for detailed time testing patterns, common pitfalls, and flaky test fixes.

## Anti-Patterns to Avoid

1. **Too many system tests** — if it doesn't need a browser, use request tests
2. **Testing Rails itself** — don't test that `validates :name, presence: true` works; test YOUR business logic
3. **Testing implementation** — `assert_received(:method)` ties tests to internals
4. **Factory cascades** — Factory Bot creating 15 records for one test; use fixtures
5. **Shared mutable state** — instance variables set in one test leaking to another
6. **Sleep-based waits** — `sleep 2` in system tests; use Capybara's built-in waiting
7. **Exact timestamp assertions** — `assert_equal Time.current, record.created_at` is flaky
8. **Testing private methods** — only test the public interface
9. **Over-mocking** — mocking everything means you're testing mocks, not code
10. **No negative tests** — always test what should fail/be denied

## Quick Reference: What to Test Where

| What | Test Type | Example |
|------|-----------|---------|
| Model validation | Model test | `refute User.new(email: nil).valid?` |
| Model scope | Model test | `assert_includes User.active, @user` |
| Business logic method | Model/Service test | `assert_equal 42, order.total` |
| API endpoint | Request test | `get api_users_url, as: :json` |
| Page renders correctly | Request test | `get root_url; assert_response :success` |
| Form submission | Request test | `post articles_url, params: {...}` |
| Auth/authorization | Request test | `get admin_url; assert_response :redirect` |
| Email content | Mailer test | `assert_equal "Welcome", email.subject` |
| Email gets sent | Request test | `assert_emails 1 { post ... }` |
| Job behavior | Job test | `perform_enqueued_jobs { MyJob.perform_later }` |
| Job gets enqueued | Model/Request test | `assert_enqueued_with(job: MyJob) { ... }` |
| JS-dependent flow | System test | `click_on "Submit"; assert_text "Done"` |
| View helper | Helper test | `assert_equal "$10", format_price(10)` |
| WebSocket channel | Channel test | `subscribe; assert_has_stream "room_1"` |
