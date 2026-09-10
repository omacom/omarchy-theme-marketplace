class ThemesController < ApplicationController
  def show
    @theme = catalog.find!(params[:slug])
    @more_by_artist = catalog.by_artist(@theme.artist_login).reject { |t| t.slug == @theme.slug }.first(3)
  end
end
