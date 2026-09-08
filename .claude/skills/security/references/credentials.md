# Credentials Management

## Editing Credentials

```bash
# Default credentials (all environments)
EDITOR=vim bin/rails credentials:edit

# Environment-specific
EDITOR=vim bin/rails credentials:edit --environment production
EDITOR=vim bin/rails credentials:edit --environment staging
```

## Structure

```yaml
# config/credentials.yml.enc (decrypted view)
secret_key_base: abc123...
aws:
  access_key_id: AKIAXXXXXXXX
  secret_access_key: xxxxxxxx
  bucket: my-app-production
stripe:
  publishable_key: pk_live_xxxx
  secret_key: sk_live_xxxx
sendgrid:
  api_key: SG.xxxx
```

## Access in Code

```ruby
Rails.application.credentials.aws[:access_key_id]
Rails.application.credentials.dig(:stripe, :secret_key)

# Bang version — raises if missing
Rails.application.credentials.stripe![:secret_key]
```

## .gitignore Rules

```gitignore
# MUST be in .gitignore
config/master.key
config/credentials/*.key
```
