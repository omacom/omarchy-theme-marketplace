# Local CI and everyday commands for the marketplace site. Run `just` to list them.
alias d := dev
alias t := test

set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Install gems, prepare the database (what CI does first)
setup:
    bin/setup --skip-server

# Rails server + Tailwind watcher on http://localhost:3000
dev:
    bin/dev

# Everything CI runs, in order: style, security scans, tests, seeds (config/ci.rb)
ci:
    bin/ci

test *args:
    bin/rails test {{ args }}

lint:
    bin/rubocop

# Auto-correct what rubocop can
fix:
    bin/rubocop -a

# Gem, importmap and code security scans
security:
    bin/bundler-audit
    bin/importmap audit
    bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error

# Apply pending migrations to development and test
migrate:
    bin/rails db:migrate
    RAILS_ENV=test bin/rails db:migrate

# Refresh data/catalog.json (the fallback used when the CDN is unreachable and in tests)
snapshot:
    curl -fsS "${CDN_BASE_URL:-https://cdn.themes.omarchy.org}/v1/catalog.json" -o data/catalog.json
    @echo "data/catalog.json: $(jq '.themes | length' data/catalog.json) themes"

console:
    bin/rails console
