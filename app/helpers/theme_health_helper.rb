module ThemeHealthHelper
  HEALTH_AREAS = {
    "validity" => [ "Theme integrity", "Palette, core colors, shell values and wallpaper files" ],
    "readability" => [ "Text & contrast", "Text on terminal, bar, menu and dialog surfaces" ],
    "semantic" => [ "State distinction", "Accent, error and selection colors" ],
    "shell" => [ "Shell surfaces", "Selected fills, focus cues and popup borders" ],
    "wallpaper" => [ "Wallpaper resilience", "Lock and launcher text over sampled wallpapers" ]
  }.freeze
  HEALTH_RULES = {
    "validity.palette" => "Palette file", "validity.roles" => "Core colors",
    "validity.shell" => "Shell values", "validity.backgrounds" => "Wallpaper files",
    "readability.foundation" => "Terminal text", "readability.selection" => "Selected terminal text",
    "readability.bar" => "Bar text", "readability.popups" => "Popup text",
    "readability.notifications" => "Notification text", "readability.menu.selected" => "Selected menu text",
    "readability.launcher.selected" => "Selected launcher text", "readability.polkit" => "Permission dialog text",
    "readability.lock" => "Lock screen text", "readability.tooltip" => "Tooltip text",
    "semantic.accent" => "Accent visibility", "semantic.error-indicator" => "Error indicator visibility",
    "semantic.selection" => "Selection distinction", "shell.selected-fill" => "Selected fill distinction",
    "shell.focus-fill" => "Focus fill distinction", "shell.popup-border" => "Popup border visibility",
    "wallpaper.lock-model" => "Lock screen wallpaper model", "wallpaper.launcher-model" => "Launcher wallpaper model"
  }.freeze
  HEALTH_SEVERITIES = { "failure" => "Problem", "caution" => "Caution", "unassessed" => "Not measured", "advisory" => "Note", "pass" => "Meets target" }.freeze
  HEALTH_METHODS = { "resolved-token" => "Resolved colors", "modeled-appearance" => "Modeled appearance", "bounded-media-decode" => "Sampled media" }.freeze

  def health_rule_label(finding) = HEALTH_RULES.fetch(finding["rule_id"], finding["rule_id"])
  def health_severity(finding) = finding["policy_suppressed"] ? "Not measured" : HEALTH_SEVERITIES.fetch(finding["severity"])
  def health_measurement(value) = number_with_precision(value, precision: 3, strip_insignificant_zeros: true)
end
