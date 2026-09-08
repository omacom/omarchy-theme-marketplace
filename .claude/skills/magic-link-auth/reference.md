# Magic Link Auth — Reference

Canonical source: Fizzy (`Authentication`, `MagicLink`, `Sessions::MagicLinksController`). Herald and Mosaic are the same idea with different tradeoffs.

## Identity vs User

37signals apps split the person from the tenant membership:

| Record | Meaning |
|--------|---------|
| **Identity** | The human. Email, magic links, sessions, access tokens. |
| **User** | Membership in an account/tenant (role, name in that workspace). |
| **Session** | A device. Belongs to Identity, not User. |

A person with one email can belong to many accounts. Sign-in authenticates the Identity; account picking happens after. Herald does the same with Identity + AccountMembership. Single-tenant apps can skip User and hang everything on Identity.

Do not put `has_many :sessions` on the tenant User. Logging out of one workspace must not require guessing which User row owns the cookie.

## Session token: `signed_id`, not a random column

Fizzy `sessions` has `identity_id`, `user_agent`, `ip_address`, timestamps. No `token` column.

```ruby
cookies.signed.permanent[:session_token] = {
  value: session.signed_id, httponly: true, same_site: :lax
}

Session.find_signed(cookies.signed[:session_token])
```

`signed_id` is tied to the UUID primary key. Destroy the row → cookie is dead. Multiple Session rows = multiple devices. `Current.identity.sessions.delete_all` logs every device out.

Herald stores `SecureRandom.urlsafe_base64(32)` in `sessions.token` and looks up with `find_by(token:)`. That works, but it is extra surface. Prefer `signed_id` for new apps.

`permanent` is ~20 years. Revocation is the Session row, not cookie expiry. Set `secure: true` in production via `config.force_ssl`.

## Pending authentication token

```ruby
Rails.application.message_verifier(:pending_authentication)
  .generate(email_address, expires_at: magic_link.expires_at)
```

Purpose: the code POST must not accept `email` from the client. The verifier cookie is the email. `verified` returns `nil` if missing, tampered, or expired — treat that as "go back to enter your email."

JSON clients get the same value in the body because they may not store cookies the way a browser does. They send it back as the `pending_authentication_token` cookie on the code POST.

Cross-identity check (Fizzy):

```ruby
ActiveSupport::SecurityUtils.secure_compare(
  email_address_pending_authentication || "",
  magic_link.identity.email_address
)
```

If a code for jason@ is submitted while the pending token is david@, fail closed, clear the pending token, do not say "wrong user."

Herald skips this and passes `email` as a param on verify. Don't copy that for new work.

## Enumeration cover

```ruby
def redirect_to_fake_session_magic_link(email_address)
  fake = MagicLink.new(
    identity: Identity.new(email_address: email_address),
    code: SecureRandom.base32(6),
    expires_at: MagicLink::EXPIRATION_TIME.from_now
  )
  redirect_to_session_magic_link fake
end
```

Not persisted, no mailer, same redirect and pending cookie as a real send. Timing still differs slightly (no INSERT/mail); rate limits and `deliver_later` keep that from being a practical oracle.

When signups are **open**, unknown emails become identities and get a real `purpose: :sign_up` code. When **closed**, fake it. Don't mix: Herald `find_or_create_by!` on every login creates an Identity for every attempted address.

## Code alphabet

Fizzy uses `SecureRandom.base32` (Crockford: digits + `ABCDEFGHJKMNPQRSTVWXYZ`, no I/L/O/U). 6 characters ≈ 32^6 ≈ 1.07e9 possibilities. Herald uses 6 digits (1e6). Mosaic uses 6 digits **hashed with bcrypt**.

Sanitize on consume:

- upcase
- `O→0`, `I→1`, `L→1`
- strip spaces, dashes, and anything outside the alphabet

That is why `MagicLink.consume("oi l-123")` can still hit a stored code.

Put `code` in `filter_parameters`. Fizzy filters `token` (catches session + pending + access tokens) but not `code` — add both.

## Consume vs `consumed_at`

| | Fizzy | Herald | Mosaic |
|--|-------|--------|--------|
| Success | `destroy` | `consumed_at = now` | `consumed_at = now` |
| Expiry | `expires_at` column | `created_at < 15.minutes.ago` | `expires_at` |
| Unused leftovers | `MagicLink.cleanup` | sit until you delete them | same as Herald |
| Extra | unique index on `code` | non-unique index | bcrypt digest, attempt counter |

Destroy-on-consume is the default. Keep `consumed_at` only if you need forensics. If you keep rows, `consume` must refuse `consumed_at.present?` and expired rows, and lookups must scope to unused + unexpired.

Mosaic hashes the code so a DB dump doesn't reveal live OTPs. Worth it if magic_links live in a database that backups/staff can read. Cost: you cannot look up by code; you load active rows for that email and `BCrypt::Password#is_password?`. Fizzy's unique index + destroy is simpler and is the 37signals default.

Mosaic also caps attempts (`MAX_ATTEMPTS = 8`) on the row. Fizzy relies on controller `rate_limit`. Use both if you store hashed codes; rate_limit is enough if codes are destroyed and the pending token binds the email.

## Sign-in vs sign-up purpose

Same code machinery, different `purpose`. After a successful `for_sign_up?` code, send the user to a **completion** form (name, account) that requires the now-authenticated identity. Don't ask for a password there.

```ruby
enum :purpose, %w[ sign_in sign_up ], prefix: :for, default: :sign_in
# magic_link.for_sign_up?
```

Identity#send_magic_link accepts `for: :sign_up` and maps it to `purpose:` so callers read like English.

## Mailer

Subject includes the code:

```ruby
mail to: identity.email_address, subject: "Your App code is #{magic_link.code}"
```

Deliver with `deliver_later`. The fake path must not enqueue a job. Preview both sign-in and sign-up templates.

Development: flash the code and set `X-Magic-Link-Code`. Guard with `after_action` that raises if `flash[:magic_link_code]` is set outside development — this leak will ship if you only hide it in the view.

## Current attributes

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :user, :account
  attribute :request_id, :user_agent, :ip_address

  def session=(value)
    super
    self.identity = session&.identity
  end
end
```

Set request metadata in a `before_action`. Copy `user_agent` / `ip_address` onto the Session at create for audit, not for auth decisions.

## Personal access tokens

For scripts and the JSON API, a second authenticator sits beside the cookie:

```ruby
class Identity::AccessToken < ApplicationRecord
  belongs_to :identity
  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  def allows?(method)
    method.in?(%w[ GET HEAD ]) || write?
  end
end

def self.find_by_permissible_access_token(token, method:)
  if (access_token = AccessToken.find_by(token: token)) && access_token.allows?(method)
    access_token.identity
  end
end
```

`require_authentication` tries cookie first, then Bearer. A read token on POST must fail.

**Show once.** After create, redirect to show with a message verifier id that expires in seconds:

```ruby
expiring_id = Rails.application.message_verifier(:access_tokens)
  .generate(access_token.id, expires_in: 10.seconds)
redirect_to my_access_token_path(expiring_id)
```

Reload/share of that URL after expiry: "Token is no longer visible." Treat the plaintext token like a password in copy.

## JSON / native-app contract (Fizzy)

`POST /session` `{ "email_address": "user@example.com" }`

- 201 `{ "pending_authentication_token": "eyJ..." }` plus `Set-Cookie`
- 422 invalid email (only when you actually validate, e.g. open signup)
- 429 rate limit

`POST /session/magic_link` `{ "code": "ABC123" }` with the pending cookie

- 200 `{ "session_token": "...", "requires_signup_completion": false }`
- 401 missing pending token / bad code / email mismatch
- 429 rate limit

Subsequent requests: `Cookie: session_token=...` or `Authorization: Bearer <access token>`. Logout: `DELETE /session` destroys the Session row and deletes the cookie.

Action Cable uses the same cookie: `Session.find_signed(cookies.signed[:session_token])`.

## Code form UX

```erb
<%= form_with url: session_magic_link_path, method: :post,
      html: { data: { controller: "magic-link" } } do |form| %>
  <%= form.text_field :code, required: true, maxlength: 6,
        autocomplete: "one-time-code", autofocus: true,
        autocorrect: "off", autocapitalize: "off", spellcheck: "false",
        data: { magic_link_target: "input",
                action: "keydown.enter->magic-link#submitOnEnter paste->magic-link#submitOnPaste" } %>
<% end %>
```

Stimulus submits on Enter/paste and disables the input to prevent double consume. Invalid code: re-render with a shake class, no explanation. iOS/Android OTP autofill needs `autocomplete="one-time-code"`.

## Rate limits

Fizzy:

- Request code: 10 per 3 minutes
- Submit code: 10 per 15 minutes

Herald: 5 per minute on create, 10 per minute on verify.

Always key by IP (Rails 8 `rate_limit` default). Mosaic also keys by email. Return the same "try later" copy for HTML and JSON (`429`).

## Testing

Exercise the HTTP flow so the signed cookie is actually set. Fizzy's helper posts email then code; Herald posts the verify path with email+code (weaker, matches its controllers).

Model tests: generate length/alphabet, `active`/`stale` scopes, consume destroys, expired consume returns nil, sanitize substitutions, cleanup.

Controller tests that catch real bugs:

- Cross-user code does not set `session_token`
- Expired pending token is unauthorized
- JSON without pending token is 401
- Fake path does not create MagicLink / Identity
- `X-Magic-Link-Code` / flash code only in development

## Herald vs Fizzy vs Mosaic

Use Fizzy's shape for new apps. Steal from the others only when the product needs it:

- **Herald** — numeric codes, `consumed_at`, email query param, `sessions.token` column, `find_or_create_by` on login, terms-of-service gate on first session. Simpler controllers; weaker binding and enumeration story.
- **Mosaic** — hashed codes, attempt counter, invite-only / allowed-domain gate, extra purposes (`cli_login`, `invite_accept`). Use when codes must not be readable in the DB or login is not open.

## Recurring cleanup

```ruby
# lib/tasks/magic_links.rake or Solid Queue recurring
MagicLink.cleanup
```

Without it, unused expired codes accumulate. Unique index on `code` means a collision retry on generate could theoretically hit a stale row if you don't clean — another reason to delete.

## Checklist for a new app

- [ ] Identity / MagicLink / Session models as above
- [ ] Unique index on `magic_links.code`, index on `expires_at`
- [ ] Pending verifier cookie; no email param on the code POST
- [ ] `secure_compare` identity email to pending email
- [ ] Fake redirect for unknown emails (unless open signup)
- [ ] Rate limits on request + verify
- [ ] Session via `signed_id` + signed cookie, HttpOnly, SameSite=Lax
- [ ] Mailer subject contains the code; `deliver_later`
- [ ] Dev-only code flash + production raise
- [ ] `filter_parameters` includes `token` and `code`
- [ ] Tests use the real POST flow
- [ ] Optional: access tokens with show-once + read/write
