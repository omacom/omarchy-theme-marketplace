Rails.application.routes.draw do
  root "home#index"

  get "themes/:slug", to: "themes#show", as: :theme
  get "authors/:login", to: "authors#show", as: :author, constraints: { login: /[A-Za-z0-9-]+/ }

  get "docs", to: "docs#show", defaults: { page: "index" }, as: :docs
  get "docs/:page", to: "docs#show", as: :doc, constraints: { page: /[a-z0-9-]+/ }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
