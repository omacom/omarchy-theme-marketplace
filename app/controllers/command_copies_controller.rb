# `POST /themes/<slug>/copied`, fired by the copy button on the theme page.
class CommandCopiesController < ApplicationController
  rate_limit name: "slug", to: 3, within: 1.day, by: -> { "#{request.remote_ip}:#{params[:slug]}" }, with: -> { head :too_many_requests }
  rate_limit name: "ip", to: 60, within: 1.hour, by: -> { request.remote_ip }, with: -> { head :too_many_requests }

  def create
    theme = catalog.find!(params[:slug])
    CommandCopy.record(theme.slug)
    render json: { slug: theme.slug, copies: CommandCopy.total_for(theme.slug) }
  end
end
