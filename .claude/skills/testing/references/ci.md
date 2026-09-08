# CI Configuration Patterns

GitHub Actions and CI setup for Rails test suites.

---

## GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports: ["6379:6379"]

    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/myapp_test
      CI: true

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Setup DB
        run: bin/rails db:test:prepare

      - name: Run tests
        run: bin/rails test

      - name: Run system tests
        run: bin/rails test:system

      - name: Upload screenshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: screenshots
          path: tmp/screenshots/
```

## Separate System Test Job (Recommended)

```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - # ... setup ...
      - run: bin/rails test
        env:
          PARALLEL_WORKERS: 4

  system-tests:
    runs-on: ubuntu-latest
    steps:
      - # ... setup ...
      - uses: browser-actions/setup-chrome@v1
      - run: bin/rails test:system
```

## Test Coverage

### SimpleCov Setup

```ruby
# Gemfile
group :test do
  gem "simplecov", require: false
end

# test/test_helper.rb (MUST be first lines)
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    minimum_coverage 80
    minimum_coverage_by_file 50
  end
end

# Run with coverage
COVERAGE=true bin/rails test
```

### What Coverage Numbers Actually Mean

- **Line coverage** — which lines executed (most common)
- **Branch coverage** — which conditional branches taken
- **100% coverage ≠ bug-free** — you can cover every line with bad assertions
- **Aim for 80-90%** — diminishing returns above that
- **Focus on business logic coverage** — models, services, policies
