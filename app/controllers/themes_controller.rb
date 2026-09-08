class ThemesController < ApplicationController
  def show
    @theme = catalog.find!(params[:slug])
    @more_by_author = catalog.by_author(@theme.author_login).reject { |t| t.slug == @theme.slug }.first(3)
  end
end
