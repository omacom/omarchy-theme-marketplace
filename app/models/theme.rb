# One entry of the published catalog (see omacom/omarchy-theme-registry, packages/schema).
# Plain value object: the catalog is read-only on the site side.
class Theme
  # Entries seeded from omarchy.org on this date are not "new" — only later submissions are.
  IMPORT_DATE = Date.new(2026, 9, 7)
  NEW_FOR_DAYS = 14

  HUE_LABELS = {
    "blue" => "Blue", "green" => "Green", "purple" => "Purple", "orange" => "Orange",
    "pink" => "Pink", "teal" => "Teal", "gray" => "Gray", "red" => "Red", "yellow" => "Yellow"
  }.freeze

  WARNING_LABELS = {
    "IGNORED_ON_INSTALL" => "Ships files Omarchy drops on install",
    "MODE_UNDECLARED" => "Light/dark mode is not declared in colors.toml",
    "MODE_CONFLICT" => "Conflicting light/dark mode declarations",
    "MODE_LUMINANCE" => "Declared mode does not match the background colour",
    "PALETTE_LEGACY" => "Palette derived from a legacy alacritty.toml",
    "PALETTE_PARTIAL" => "Palette is missing optional colours",
    "PALETTE_UNKNOWN_KEYS" => "colors.toml has keys Omarchy ignores",
    "PALETTE_BAD_VALUE" => "Some optional palette values are not valid colours",
    "BACKGROUNDS_NONE" => "No wallpapers included",
    "BACKGROUNDS_LARGE" => "Wallpapers are large (slow install)",
    "BACKGROUND_HEAVY" => "Some wallpapers are heavy",
    "BACKGROUND_VIDEO" => "Includes video wallpapers",
    "BACKGROUND_SKIPPED" => "Some wallpaper files will be ignored by Omarchy",
    "BACKGROUND_FILENAME" => "Wallpaper filenames contain spaces or unusual characters",
    "PREVIEW_ASPECT" => "Preview is not 16:9",
    "NO_README" => "No README",
    "NO_LICENSE_FILE" => "No LICENSE file",
    "REPO_NO_LICENSE" => "No recognised license",
    "REPO_NO_TOPIC" => "Missing the omarchy-theme GitHub topic",
    "REPO_NAME_CONVENTION" => "Repository name does not follow omarchy-<name>-theme",
    "REPO_ARCHIVED" => "Repository is archived",
    "REPO_MOVED" => "Repository has moved",
    "NON_THEME_PAYLOAD" => "Contains scripts or binaries (never run by Omarchy)",
    "VSCODE_EXTENSION" => "Names a VS Code extension (ignored on install)",
    "VSCODE_JSON_INVALID" => "vscode.json is invalid",
    "ICONS_THEME_UNKNOWN" => "Unknown icon theme",
    "KEYBOARD_RGB_INVALID" => "keyboard.rgb is invalid",
    "UNLOCK_PAIR" => "Unlock screen images are incomplete"
  }.freeze

  ATTRS = %i[slug name repo author description license mode hue colors generation ignored_on_install
             backgrounds preview commit pushed_at stars added_at tags featured warnings install].freeze

  attr_reader(*ATTRS)

  def initialize(data)
    data = data.to_h.transform_keys(&:to_s)
    @slug = data["slug"]
    @name = data["name"]
    @repo = data["repo"]
    @author = data.fetch("author", {}).transform_keys(&:to_s)
    @description = data["description"]
    @license = data["license"]
    @mode = data["mode"]
    @hue = data["hue"]
    @colors = data.fetch("colors", {}).transform_keys(&:to_s)
    @generation = data["generation"]
    @ignored_on_install = Array(data["ignored_on_install"])
    @backgrounds = data.fetch("backgrounds", {}).transform_keys(&:to_s)
    @preview = data.fetch("preview", {}).transform_keys(&:to_s)
    @commit = data["commit"]
    @pushed_at = data["pushed_at"] && Time.iso8601(data["pushed_at"])
    @stars = data["stars"].to_i
    @added_at = data["added_at"] && Date.iso8601(data["added_at"])
    @tags = Array(data["tags"])
    @featured = data["featured"] == true
    @warnings = Array(data["warnings"])
    @install = data["install"]
  end

  def to_param = slug
  def author_login = author["login"]
  def author_url = author["url"]
  def image = preview["src"]
  def thumb = preview["thumb"]
  def placeholder = preview["placeholder"]
  def featured? = featured
  def dark? = mode == "dark"
  def light? = mode == "light"
  def accent = colors["accent"]
  def background = colors["background"]
  def foreground = colors["foreground"]
  def hue_label = HUE_LABELS.fetch(hue, hue.to_s.capitalize)
  # Engagement stats live in the site database; see Engagement.
  def stats = @stats ||= Engagement.for(slug)
  def likes = stats.likes
  def copies = stats.copies
  def trending = stats.trending
  def short_commit = commit.to_s[0, 7]

  def new?
    added_at.present? && added_at > IMPORT_DATE && added_at >= Date.current - NEW_FOR_DAYS
  end

  def warning_labels
    warnings.map { |w| WARNING_LABELS[w] }.compact.uniq
  end

  PALETTE_ROWS = [
    %w[accent background foreground],
    %w[red yellow green cyan blue magenta],
    %w[bright_red bright_yellow bright_green bright_cyan bright_blue bright_magenta]
  ].freeze

  # Palette as displayed: accent/background/foreground, the six base colours, their bright
  # variants. Surfaces and extras (orange, brown, selection, muted…) are left out.
  def palette_rows
    PALETTE_ROWS.map { |row| row.filter_map { |k| colors[k] && [ k, colors[k] ] } }.reject(&:empty?)
  end

  def palette = palette_rows.flatten(1)

  def commit_url = "#{repo}/commit/#{commit}"
  def issues_url = "#{repo}/issues"
end
