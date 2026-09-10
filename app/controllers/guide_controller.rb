class GuideController < ApplicationController
  # One page: everything from making a theme to installing it lives in guide/pages/index.md,
  # as sections a reader can jump to. "api" stays unlisted (kept in guide/pages/api.md) until the
  # CDN moves to its production domain.
  PAGES = { "index" => "Guide" }.freeze

  # Page → markdown file, resolved once from the allowlist so no request value touches a path.
  FILES = PAGES.keys.index_with { |page| Rails.root.join("app/views/guide/pages", "#{page}.md") }.freeze

  def show
    @page = PAGES.keys.find { |page| page == (params[:page].presence || "index") }
    raise ActiveRecord::RecordNotFound, "No guide page #{params[:page]}" unless @page
    @title = PAGES.fetch(@page)
    @html = render_markdown(FILES.fetch(@page).read)
  end

  private

  def render_markdown(source)
    Kramdown::Document.new(source, input: "GFM", syntax_highlighter: nil, hard_wrap: false).to_html
  end
end
