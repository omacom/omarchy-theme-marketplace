class AuthorsController < ApplicationController
  def show
    @login = params[:login]
    @themes = catalog.by_author(@login).sort_by { |t| t.name.downcase }
    raise ActiveRecord::RecordNotFound, "No themes by #{@login}" if @themes.empty?
    @login = @themes.first.author_login
  end
end
