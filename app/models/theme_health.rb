# Optional advisory data from the registry. Never changes theme eligibility or ordering.
# Unknown/malformed reports are absent; a grade only describes its exact source commit.
class ThemeHealth
  CATEGORIES = %w[validity readability semantic shell wallpaper].freeze
  GRADES = %w[A B C D F].freeze
  SHA = /\A[0-9a-f]{40}\z/
  FINGERPRINT = /\A[0-9a-f]{64}\z/
  RULE_ID = /\A[a-z][a-z0-9.-]{0,95}\z/
  HEX = /\A#[0-9a-f]{6}\z/i
  FIELDS = %w[schema_version commit runtime_commit analyzer_version ruleset_version profile input_fingerprint checked_at state grade summary cap_reasons categories findings assumptions].freeze
  FINDING_FIELDS = %w[rule_id category severity scored assessment_status policy_suppressed method summary remediation reason sources measurement].freeze
  EMPTY = [].freeze

  attr_reader :data, :checked_at

  def initialize(data, commit:)
    @current_commit = commit.to_s.dup.freeze
    if valid?(data)
      @data = deep_freeze(data.deep_dup)
      @checked_at = Time.iso8601(data.fetch("checked_at")).freeze
    end
    freeze
  end

  def available? = !data.nil?
  def current? = available? && data["commit"] == @current_commit
  def outdated? = available? && !current?
  def graded? = current? && GRADES.include?(data["grade"])
  def provisional? = current? && data["state"] == "provisional"
  def grade_label = graded? ? "#{data['grade']}#{'*' if provisional?}" : nil
  def state = !available? ? "not-checked" : outdated? ? "outdated" : data["state"]
  def summary = data&.fetch("summary", nil)
  def categories = data&.fetch("categories", EMPTY) || EMPTY
  def findings = data&.fetch("findings", EMPTY) || EMPTY
  def findings_for(id) = findings.select { |f| f["category"] == id }
  def issues_for(id) = findings_for(id).reject { |f| f["severity"] == "pass" && !f["policy_suppressed"] }
  def passed_for(id) = findings_for(id).select { |f| f["severity"] == "pass" && !f["policy_suppressed"] }
  def count(severity) = findings.count { |f| f["scored"] && !f["policy_suppressed"] && f["severity"] == severity }
  def unmeasured_count = findings.count { |f| f["scored"] && (f["policy_suppressed"] || f["assessment_status"] == "unassessed") }

  private
    def text?(value, max = 2000) = value.is_a?(String) && value.length <= max
    def texts?(value, max) = value.is_a?(Array) && value.size <= max && value.all? { |v| text?(v) }
    def boolean?(value) = value == true || value == false
    def letter?(value) = value.nil? || GRADES.include?(value)

    def valid?(value)
      return false unless value.is_a?(Hash) && value["schema_version"] == 1 && (value.keys - FIELDS).empty?
      return false unless JSON.generate(value).bytesize <= 96 * 1024
      return false unless %w[commit runtime_commit].all? { |k| SHA.match?(value[k].to_s) }
      return false unless FINGERPRINT.match?(value["input_fingerprint"].to_s)
      return false unless %w[analyzer_version ruleset_version profile].all? { |k| text?(value[k], 100) && value[k].present? }
      return false unless %w[ready provisional not-graded].include?(value["state"]) && letter?(value["grade"])
      return false unless (value["state"] == "not-graded") == value["grade"].nil?
      return false unless text?(value["summary"]) && texts?(value["assumptions"], 20) && texts?(value["cap_reasons"], 30)
      return false unless value["cap_reasons"].all? { |id| RULE_ID.match?(id) }
      return false unless value["checked_at"].is_a?(String)
      Time.iso8601(value["checked_at"])
      categories = value["categories"]
      return false unless categories.is_a?(Array) && categories.size == 5 && categories.all? { |c| valid_category?(c) }
      return false unless categories.map { |c| c["id"] }.sort == CATEGORIES.sort
      return false if value["state"] == "ready" && categories.any? { |c| %w[limited not-checked].include?(c["state"]) }
      findings = value["findings"]
      findings.is_a?(Array) && findings.size <= 100 && findings.all? { |f| valid_finding?(f) } &&
        findings.map { |f| f["rule_id"] }.uniq.size == findings.size
    rescue ArgumentError, TypeError, JSON::GeneratorError
      false
    end

    def valid_category?(value)
      value.is_a?(Hash) && (value.keys - %w[id grade state summary]).empty? && CATEGORIES.include?(value["id"]) && letter?(value["grade"]) &&
        %w[ready limited not-checked not-applicable].include?(value["state"]) && text?(value["summary"]) &&
        (%w[not-checked not-applicable].include?(value["state"]) == value["grade"].nil?)
    end

    def valid_finding?(value)
      return false unless value.is_a?(Hash) && (value.keys - FINDING_FIELDS).empty? && text?(value["rule_id"], 96) && RULE_ID.match?(value["rule_id"])
      return false unless CATEGORIES.include?(value["category"]) && %w[pass caution failure advisory unassessed].include?(value["severity"])
      return false unless boolean?(value["scored"]) && boolean?(value["policy_suppressed"])
      return false unless %w[assessed unassessed not-applicable].include?(value["assessment_status"])
      return false unless %w[resolved-token modeled-appearance bounded-media-decode].include?(value["method"])
      return false unless %w[summary remediation].all? { |k| text?(value[k]) }
      return false if value.key?("reason") && !text?(value["reason"])
      sources = value["sources"]
      return false unless sources.is_a?(Array) && sources.size <= 30 && sources.all? { |s| s.is_a?(Hash) && (s.keys - %w[file section key]).empty? && %w[file section key].all? { |k| text?(s[k], 300) } }
      !value.key?("measurement") || valid_measurement?(value["measurement"])
    end

    def valid_measurement?(value)
      value.is_a?(Hash) && (value.keys - %w[kind value target foreground background]).empty? && %w[contrast distance].include?(value["kind"]) &&
        %w[value target].all? { |k| value[k].is_a?(Numeric) && value[k].finite? && value[k] >= 0 } &&
        value["target"] > 0 && %w[foreground background].all? { |k| !value.key?(k) || HEX.match?(value[k].to_s) }
    end

    def deep_freeze(value)
      case value
      when Hash then value.each { |key, child| key.freeze; deep_freeze(child) }
      when Array then value.each { |child| deep_freeze(child) }
      end
      value.freeze
    end
end
