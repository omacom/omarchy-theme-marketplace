class HomeController < ApplicationController
  def index
    @query = ThemeQuery.new(catalog, params)
    @stats = {
      "Themes published" => catalog.size,
      "Theme authors" => catalog.authors.size,
      "Dark themes" => catalog.dark.size,
      "Light themes" => catalog.light.size
    }
  end
end
