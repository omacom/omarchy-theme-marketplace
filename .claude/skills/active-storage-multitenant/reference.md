# Active Storage + tenanted — Reference

Herald is the reference implementation. Files:

| Path | Role |
|------|------|
| `app/models/active_storage/tenant_signed_id.rb` | Sign/verify `{ id, tenant }` |
| `app/controllers/direct_uploads_controller.rb` | Tenant-aware create |
| `app/controllers/concerns/active_storage/tenanted_set_blob.rb` | Lookup |
| `app/controllers/concerns/active_storage_tenant_scoping.rb` | `with_tenant_from_key` from blob.key prefix |
| `app/controllers/active_storage/blobs/redirect_controller.rb` | Override engine |
| `app/controllers/active_storage/representations/base_controller.rb` | Variants |
| `app/controllers/active_storage/representations/redirect_controller.rb` | Variant redirect |

No Active Storage route overrides. Nested `post :direct_uploads` on the record that knows the tenant (project/account).

## Lookup algorithm

```
verify signed_id
if tenant in payload:
  if query tenant present AND != signed tenant → 404
  load blob in that shard
else:  # legacy
  if query tenant present → 404  # do not trust the hint
  scan all tenants with a database
  0 matches → 404
  1 match → use it
  2+ → 404
set current_tenant for the rest of the request
```

At large tenant counts, scanning is slow. The signed tenant in the payload is the real fix; the scan is only for old URLs.

## Why preview works and view doesn't

Direct upload returns a short-lived S3 PUT plus a preview URL that still has request context. After save, the page uses `/rails/active_storage/blobs/redirect/:signed_id` with no tenant. That's why you only notice after reload.

## Fizzy (not this gem)

Fizzy is same-DB tenancy. It patches `accessible_to?` on blobs and blocks cross-account blob reuse. Don't copy Herald's tenant-scan into Fizzy, and don't copy Fizzy's ACL patch into Herald without the signed tenant id.
