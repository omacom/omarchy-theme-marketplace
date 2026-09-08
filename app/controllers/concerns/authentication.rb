# Cookie-backed sessions (a row per sign-in, so "sign out everywhere" is a delete).
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :current_user, :signed_in?
  end

  private

  def current_user = Current.user
  def signed_in? = current_user.present?

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    id = cookies.signed[:session_id]
    Session.includes(:user).find_by(id: id) if id
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent.to_s[0, 255], ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax, secure: request.ssl? }
    end
  end

  def terminate_session
    Current.session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
  end

  def require_login
    return if signed_in?
    session[:return_to] = request.fullpath if request.get?
    session[:return_to] ||= request.referer if request.referer.present?
    respond_to do |format|
      format.html { redirect_to login_path, notice: "Sign in with GitHub to continue." }
      format.turbo_stream { redirect_to login_path, notice: "Sign in with GitHub to continue." }
      format.any { head :unauthorized }
    end
  end

  def return_to_path(default = root_path)
    path = session.delete(:return_to)
    path.present? && path.start_with?("/") && !path.start_with?("//") ? path : default
  end
end
