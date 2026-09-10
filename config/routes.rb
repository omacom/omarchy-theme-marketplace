Rails.application.routes.draw do
  root "home#index"

  get "themes/:slug", to: "themes#show", as: :theme
  post "themes/:slug/like", to: "likes#create", as: :theme_like
  post "themes/:slug/copied", to: "command_copies#create", as: :theme_copied
  delete "themes/:slug/like", to: "likes#destroy"
  get "artists", to: "artists#index", as: :artists
  get "artists/:login", to: "artists#show", as: :artist, constraints: { login: /[A-Za-z0-9-]+/ }

  get "guide", to: "guide#show", defaults: { page: "index" }, as: :guide
  get "guide/:page", to: "guide#show", as: :guide_page, constraints: { page: /[a-z0-9-]+/ }

  # Sign in with GitHub (OmniAuth handles POST /auth/github).
  get "login", to: "sessions#new", as: :login
  get "auth/github/callback", to: "sessions#create"
  get "auth/failure", to: "sessions#failure"
  delete "logout", to: "sessions#destroy", as: :logout
  get "me", to: "me#show", as: :me

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
