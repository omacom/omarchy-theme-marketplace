class ArtistsController < ApplicationController
  SORTS = { "themes" => "Most themes", "name" => "Name" }.freeze

  def index
    @sort = SORTS.key?(params[:sort].to_s) ? params[:sort].to_s : "themes"
    @artists = catalog.artist_stats
    @artists = @artists.sort_by { |a| a[:login].downcase } if @sort == "name"
  end

  def show
    @login = params[:login]
    @themes = catalog.by_artist(@login).sort_by { |t| t.name.downcase }
    raise ActiveRecord::RecordNotFound, "No themes by #{@login}" if @themes.empty?
    @login = @themes.first.artist_login
  end
end
