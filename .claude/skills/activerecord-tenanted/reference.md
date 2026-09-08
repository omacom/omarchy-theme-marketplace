# activerecord-tenanted — Reference

Gem: [basecamp/activerecord-tenanted](https://github.com/basecamp/activerecord-tenanted). Canonical apps: Herald, Cortex, Innkeeper.

## Not this skill

| Model | What it is | Use instead |
|-------|------------|-------------|
| **Nebula** | `acts_as_tenant :workspace`, one Postgres, `workspace_id` on rows, `Current.workspace` | Follow Nebula's `docs/tenant-bound-models.md` |
| **Fizzy** | Shared MySQL/SQLite, tenant is URL `SCRIPT_NAME` + `Current.account` | Path tenancy, not a second database |

Do not "port" those into `tenanted: true` SQLite. The failure modes (missing `workspace_id` vs missing shard) look similar and the fix is not.

## Topology

Five SQLite files is the house default:

```
storage/{env}.sqlite3                          # global
storage/tenants/{env}/{tenant_key}/main.sqlite3 # one per tenant
storage/{env}_queue.sqlite3
storage/{env}_cache.sqlite3
storage/{env}_cable.sqlite3
```

`max_connection_pools: 50` on `primary` — each tenant is a pool. Tune if you have many concurrent tenants.

Herald sets `database_tasks: false` on primary so `db:prepare` doesn't treat `%{tenant}` as a single file. Cortex omits that. Follow whichever app you're in.

## Tenant key

Must be filesystem-safe and stable:

- Cortex/Innkeeper: `tenant.external_id` (short numeric or UUID-ish slug)
- Herald: `"account-#{account.id}"`

Never use the display name. Changing a slug must not rename the database unless you migrate files.

`ApplicationRecord.create_tenant(key)` creates the directory, file, and runs tenant migrations. Rescue `TenantExistsError` in tests.

## Shard swapping

`ApplicationRecord.current_tenant = key` is what actually switches. `Current.tenant=` is only a wrapper.

`ActiveRecord::Base.shard_swapping_prohibited?` is true inside some AR internals and nested connections. Swallowing only `"shard"` `ArgumentError`s (Herald/Cortex) is the established workaround — don't rescue everything.

Untenanted sentinel: `ActiveRecord::Tenanted::Tenant::UNTENANTED_SENTINEL`. Setting `current_tenant = nil` is not always equivalent. Cortex resets to the sentinel in `Current.resets`.

## Nested with_tenant

`with_tenant` restores the previous tenant on exit. Safe to nest. Not safe to start a background thread and assume the shard is still set.

## Associations across the split

There is **no foreign key** from a tenanted table to a global table at the database level — they are different files.

```ruby
# Tenanted User → global Identity
class User < ApplicationRecord
  # identity_id is just a UUID column. No `belongs_to :identity` FK.
  def identity
    Identity.find_by(id: identity_id)
  end
end
```

Cortex uses `belongs_to :identity, class_name: "Identity"` anyway (cross-db). It works for in-memory loads when both connections are up; it will not enforce FK. Don't `dependent: :destroy` across the split without wrapping both databases.

## Migrations

```
db/global_migrate/20260101000001_create_identities.rb
db/migrate/20260101000002_create_users.rb          # per tenant
```

A new tenanted table is a `db/migrate` file. Existing tenants get it on next `db:migrate`. New tenants get it on `create_tenant`.

Don't put a tenanted table in `global_migrate`. Don't put Identity in `db/migrate`.

## Console

```ruby
ApplicationRecord.with_tenant("acme") { User.count }
Current.tenant = Tenant.find_by(external_id: "acme")
```

Without that, tenanted queries raise or hit the local default tenant (dev only).

## Parallel tests

Each test worker needs distinct tenant files. `create_tenant` + `TenantExistsError` is how Herald stays idempotent. Don't share one tenant key across examples that mutate schema.

## Checklist

- [ ] `ApplicationRecord` `tenanted`; `GlobalRecord` `connects_to :global`
- [ ] `tenant_resolver` returns `nil`; production `default_tenant` is `nil`
- [ ] `Current.tenant=` / `Current.account=` sets `ApplicationRecord.current_tenant`
- [ ] Controllers set Current from a **global** lookup (slug, external_id), then shard
- [ ] Jobs take a tenant key, then `with_tenant`
- [ ] Rake iterates `Tenant.find_each`
- [ ] Active Storage uses `tenanted_rails_records` + the multitenant skill
