# Outgoing Webhooks — Reference

## Fizzy vs Herald

| | Fizzy | Herald |
|--|-------|--------|
| Scope | Board | Project (account tenant DB) |
| Secret | `has_secure_token :signing_secret` | `whsec_` + urlsafe_base64 |
| SSRF | Always; `SsrfProtection` + `http.ipaddr` | Production only; same pin idea |
| Failure policy | Delinquency tracker | 10 consecutive → auto-disable |
| Trigger | `Event` → `WebhookDispatchJob` | `PublishReleaseJob` enqueues `DeliverWebhookJob` |
| Payload | Event-specific, Slack/Campfire shaping | JSON `release.published` |

For a new tenanted SaaS app, start from Herald's job/claim/auto-disable and Fizzy's always-on IP pin + response size cap.

## SSRF details

DNS rebinding: resolve, check public, then connect to that IP while the TLS SNI/Host header stays the original hostname (`Net::HTTP#ipaddr`). If you connect by hostname, a second lookup can hit a private address.

Also block:

- `0.0.0.0/8`, CGNAT `100.64.0.0/10`, benchmark `198.18.0.0/15`
- IPv4-mapped IPv6 (`::ffff:127.0.0.1`) — call `ip.native` before matching
- `file:`, `gopher:`, `http://0/`

Don't use a user-controlled URL as `URI.open` / `Kernel.open`.

## Claiming a delivery

```ruby
WebhookDelivery
  .where(id: delivery.id, delivered_at: nil, failed_at: nil)
  .where("delivering_at IS NULL OR delivering_at < ?", CLAIM_TIMEOUT.ago)
  .update_all(delivering_at: Time.current) == 1
```

If the update isn't exactly 1, another worker owns it. Stale `delivering_at` (worker died) can be reclaimed after `CLAIM_TIMEOUT`.

## Entitlements

If webhooks are a paid feature, re-check the plan **in the job**. A tenant can downgrade between enqueue and perform. Herald records a terminal failure without counting it against the endpoint when the entitlement is gone.

## What not to copy

Fizzy's `STALE_TRESHOLD` typo and Slack-specific payload shaping unless you need chat product URLs. Don't subscribe to "all events" by default — allowlist actions.
