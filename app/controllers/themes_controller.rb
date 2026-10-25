class ThemesController < ApplicationController
  def show
    @theme = catalog.find!(params[:slug])
    @more_by_artist = catalog.by_artist(@theme.artist_login).reject { |t| t.slug == @theme.slug }.first(3)
    @similar = catalog.similar_to(@theme)
  end

  def health
    theme = catalog.find!(params[:slug])
    return head :not_found unless theme.health.current?

    render json: theme.health.data
  end
end
