class LikesController < ApplicationController
  before_action :require_login
  before_action :set_theme

  def create
    current_user.likes.find_or_create_by!(slug: @theme.slug)
    respond
  end

  def destroy
    current_user.likes.where(slug: @theme.slug).destroy_all
    respond
  end

  private

  def set_theme
    @theme = catalog.find!(params[:slug])
  end

  def respond
    current_user.likes.reset
    @theme.instance_variable_set(:@stats, nil)
    Engagement.expire
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("like-#{@theme.slug}", partial: "themes/like_button", locals: { theme: @theme }) }
      format.html { redirect_back_or_to theme_path(@theme) }
    end
  end
end
