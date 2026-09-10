class MeController < ApplicationController
  before_action :require_login

  def show
    liked = current_user.likes.order(created_at: :desc).pluck(:slug)
    @liked_themes = liked.filter_map { |slug| catalog.find(slug) }
    @own_themes = catalog.by_artist(current_user.login)
  end
end
