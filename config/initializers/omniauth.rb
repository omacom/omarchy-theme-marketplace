# Sign in with GitHub. Create an OAuth app at github.com/settings/developers with the callback
# URL <site>/auth/github/callback and put its id/secret in GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
           ENV.fetch("GITHUB_CLIENT_ID", "unset"),
           ENV.fetch("GITHUB_CLIENT_SECRET", "unset"),
           scope: "" # public profile only
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = proc { |env| SessionsController.action(:failure).call(env) }
OmniAuth.config.test_mode = Rails.env.test?
