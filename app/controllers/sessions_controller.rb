class SessionsController < ApplicationController
  def new
    redirect_to return_to_path if signed_in?
  end

  def create
    user = User.from_github(request.env["omniauth.auth"])
    start_new_session_for(user)
    redirect_to return_to_path, notice: "Signed in as #{user.login}."
  end

  def failure
    redirect_to login_path, alert: "GitHub sign-in did not complete (#{params[:message].to_s.humanize.downcase.presence || 'unknown error'})."
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "Signed out."
  end
end
