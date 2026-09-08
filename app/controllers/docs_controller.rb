class DocsController < ApplicationController
  PAGES = {
    "index" => "Documentation",
    "making-a-theme" => "Making a theme",
    "validation" => "What gets checked",
    "installing" => "Installing themes"
    # "api" => "Catalog API" — hidden until the CDN moves to its production domain (page kept in docs/pages/api.md)
  }.freeze

  # Page → markdown file, resolved once from the allowlist so no request value touches a path.
  FILES = PAGES.keys.index_with { |page| Rails.root.join("app/views/docs/pages", "#{page}.md") }.freeze

  def show
    @page = PAGES.keys.find { |page| page == (params[:page].presence || "index") }
    raise ActiveRecord::RecordNotFound, "No doc #{params[:page]}" unless @page
    @title = PAGES.fetch(@page)
    @html = render_markdown(FILES.fetch(@page).read)
    @pages = PAGES
  end

  private

  def render_markdown(source)
    Kramdown::Document.new(source, input: "GFM", syntax_highlighter: nil, hard_wrap: false).to_html
  end
end
