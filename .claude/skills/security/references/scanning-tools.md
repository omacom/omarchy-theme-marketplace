# Security Scanning Tools

## Brakeman (Static Analysis)

```bash
# Install
gem install brakeman

# Run
brakeman -p /path/to/rails/app

# CI-friendly output
brakeman -p . -f json -o brakeman-report.json

# Check specific files
brakeman -p . --only-files app/controllers/
```

## bundle-audit (Dependency Vulnerabilities)

```bash
# Install
gem install bundler-audit

# Update vulnerability database
bundle-audit update

# Check Gemfile.lock
bundle-audit check

# CI: fail on vulnerabilities
bundle-audit check --update
```

## importmap:audit (JavaScript Dependencies)

```bash
# Rails 7+ with importmaps
bin/rails importmap:audit
```

## Quick Security Wins

1. **`force_ssl = true`** in production — one line, massive protection
2. **`config.filter_parameters`** — add all sensitive field names
3. **Run `brakeman`** — catches most static vulnerabilities
4. **Run `bundle-audit`** — catches known CVEs in gems
5. **Use `url_from`** for redirects — eliminates open redirects
6. **Use hash conditions** in `where()` — eliminates most SQL injection
7. **Never call `.html_safe`** on anything touching user input
8. **Add CSP headers** — even a basic policy helps
9. **Rate limit auth endpoints** — one line per controller
10. **Scope queries to current user** — prevents most authorization bugs
