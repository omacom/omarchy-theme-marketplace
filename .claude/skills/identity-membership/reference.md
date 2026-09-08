# Identity / Membership — Reference

## App map

| | Auth person | Workspace | Join | In-workspace person |
|--|-------------|-----------|------|---------------------|
| **Herald** | `Identity` (global) | `Account` (global) | `AccountMembership` (global) | none — identity is enough |
| **Cortex / Innkeeper** | `Identity` (global) | `Tenant` (global) | `Membership` (global) | `User` (tenanted, `identity_id`) |
| **Fizzy** | `Identity` | `Account` | `User` (same DB, `identity` + account) | User **is** the membership |

All three authenticate Identity with magic links. Sessions never belong to User.

## After sign-in routing

1. Join-code pending in session → redeem, go to that tenant.
2. Zero memberships → create workspace / first project.
3. One membership → that tenant's dashboard.
4. Many → picker. Don't guess.

Herald also has project-level `Membership` (legacy) plus account-level `AccountMembership`. New work uses account-level.

## Super-admin (Cortex)

`Identity.system_role` (`standard` / `super_admin`) is **not** a Membership. Super-admins may auto-provision a User on visit and skip `require_membership!`. Revoke must delete that tenanted User. Don't copy this unless you need mission-control access across all shards.

## Join code format

Herald/Fizzy: Base58 groups `XXXX-XXXX-XXXX`. Usage limit + `usage_count`. `reset!` rotates the code (old links die). `redeem_if` locks the row so two redeemers can't blow the cap.

Store the code on the global DB even in tenanted apps — the visitor hits `/join/:code` before a tenant is in the URL.

## Tests

```ruby
def sign_in_as(identity)
  # magic-link HTTP flow — see magic-link-auth
end

def join!(identity, tenant, role: :member)
  identity.join(tenant, role: role)
end
```

Assert: Identity with no Membership gets 403 on a tenant URL while still having a session cookie. Assert: joining twice doesn't duplicate User.

## Current cheat sheet

| Attribute | Database | Set by |
|-----------|----------|--------|
| `Current.identity` | global | cookie / bearer |
| `Current.session` | global | cookie |
| `Current.tenant` / `account` | global | URL |
| `Current.user` | tenanted (or Fizzy same-DB) | TenantScoping after both of the above |
