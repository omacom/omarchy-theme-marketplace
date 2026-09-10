require "net/http"

# The published theme catalog. Fetched from the CDN and cached for a few minutes; the snapshot
# in data/catalog.json is the fallback when the CDN is unreachable (and the source in tests).
class Catalog
  CACHE_KEY = "catalog:v1"
  TTL = 5.minutes
  SNAPSHOT = Rails.root.join("data/catalog.json")

  Error = Class.new(StandardError)

  class << self
    def current
      new(Rails.cache.fetch(CACHE_KEY, expires_in: TTL) { load_data })
    end

    def url
      Rails.configuration.x.catalog_url
    end

    def load_data
      remote = url.present? ? fetch_remote : nil
      remote || snapshot
    end

    def fetch_remote
      uri = URI(url)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        http.get(uri.request_uri, { "Accept" => "application/json", "User-Agent" => "omarchy-themes-site" })
      end
      raise Error, "catalog fetch failed: HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    rescue StandardError => e
      Rails.logger.warn("[catalog] #{e.class}: #{e.message}; using snapshot")
      nil
    end

    def snapshot
      JSON.parse(File.read(SNAPSHOT))
    end
  end

  attr_reader :generated_at, :schema_version

  def initialize(data)
    @schema_version = data["schema_version"]
    @generated_at = data["generated_at"] && Time.iso8601(data["generated_at"])
    @themes = data.fetch("themes", []).map { |t| Theme.new(t) }
    @by_slug = @themes.index_by(&:slug)
  end

  def themes = @themes
  def size = @themes.size
  def find(slug) = @by_slug[slug]
  def find!(slug) = find(slug) || raise(ActiveRecord::RecordNotFound, "No theme #{slug.inspect}")
  def any_featured? = @themes.any?(&:featured?)
  def artists = @themes.map(&:artist_login).uniq
  def by_artist(login) = @themes.select { |t| t.artist_login.casecmp?(login) }
  def new_themes = @themes.select(&:new?)
  def dark = @themes.select(&:dark?)
  def light = @themes.select(&:light?)
end
