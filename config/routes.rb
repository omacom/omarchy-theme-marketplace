Rails.application.routes.draw do
  root "home#index"

  get "themes", to: redirect("/#themes")
  get "themes/:slug", to: "themes#show", as: :theme
  get "artists", to: "artists#index", as: :artists
  get "artists/:login", to: "artists#show", as: :artist, constraints: { login: /[A-Za-z0-9-]+/ }

  get "guide", to: "guide#show", defaults: { page: "index" }, as: :guide
  get "guide/:page", to: "guide#show", as: :guide_page, constraints: { page: /[a-z0-9-]+/ }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
