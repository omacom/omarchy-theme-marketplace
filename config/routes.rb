Rails.application.routes.draw do
  root "home#index"

  get "themes", to: redirect("/#themes")
  # Slugs may contain dots ("foo.v2"), which Rails would otherwise read as a format.
  get "themes/:slug/health", to: "themes#health", as: :theme_health, constraints: { slug: %r{[^/]+} }, format: false, defaults: { format: :json }
  get "themes/:slug", to: "themes#show", as: :theme, constraints: { slug: %r{[^/]+} }, format: false
  get "artists", to: "artists#index", as: :artists
  get "artists/:login", to: "artists#show", as: :artist, constraints: { login: /[A-Za-z0-9-]+/ }

  get "guide", to: "guide#show", defaults: { page: "index" }, as: :guide
  get "guide/:page", to: "guide#show", as: :guide_page, constraints: { page: /[a-z0-9-]+/ }

  get "sitemap.xml", to: "seo#sitemap", as: :sitemap, format: false, defaults: { format: :xml }
  get "robots.txt", to: "seo#robots", as: :robots, format: false

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
