class DocsController < ApplicationController
  PAGES = {
    "index" => "Documentation",
    "making-a-theme" => "Making a theme",
    "validation" => "What gets checked",
    "installing" => "Installing themes"
    # "api" => "Catalog API" — hidden until the CDN moves to its production domain (page kept in docs/pages/api.md)
  }.freeze

  def show
    @page = params[:page].presence || "index"
    raise ActiveRecord::RecordNotFound, "No doc #{@page}" unless PAGES.key?(@page)
    @title = PAGES[@page]
    source = Rails.root.join("app/views/docs/pages", "#{@page}.md").read
    @html = Kramdown::Document.new(source, input: "GFM", syntax_highlighter: nil, hard_wrap: false).to_html
    @pages = PAGES
  end
end
