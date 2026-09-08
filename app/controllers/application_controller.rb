class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :catalog

  rescue_from ActiveRecord::RecordNotFound do
    render "errors/not_found", status: :not_found
  end

  private

  def catalog
    @catalog ||= Catalog.current
  end
end
