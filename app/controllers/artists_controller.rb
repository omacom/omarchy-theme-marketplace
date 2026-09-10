class ArtistsController < ApplicationController
  def show
    @login = params[:login]
    @themes = catalog.by_artist(@login).sort_by { |t| t.name.downcase }
    raise ActiveRecord::RecordNotFound, "No themes by #{@login}" if @themes.empty?
    @login = @themes.first.artist_login
  end
end
