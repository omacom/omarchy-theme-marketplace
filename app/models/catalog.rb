require "net/http"

# The published theme catalog. Fetched from the CDN and cached for a few minutes. When the CDN is
# unreachable the site keeps serving the last catalog it fetched; the snapshot in data/catalog.json
# is only for a process that has never reached the CDN (a cold boot during an outage, and tests).
class Catalog
  CACHE_KEY = "catalog:v1"
  TTL = 5.minutes
  # While serving a fallback, try the CDN again this soon.
  RETRY_TTL = 1.minute
  SNAPSHOT = Rails.root.join("data/catalog.json")

  Error = Class.new(StandardError)

  class << self
    def current
      new(Rails.cache.read(CACHE_KEY) || refresh)
    end

    def url
      Rails.configuration.x.catalog_url
    end

    # The snapshot can be weeks old and still list themes that have since left the catalog, so a
    # fetched copy, however stale, is the better fallback.
    def refresh
      if (data = url.present? ? fetch_remote : nil)
        @last_fetched = data
        Rails.cache.write(CACHE_KEY, data, expires_in: TTL)
      else
        data = @last_fetched || snapshot
        Rails.logger.warn("[catalog] serving the #{@last_fetched ? "last fetched catalog" : "snapshot"}") if url.present?
        Rails.cache.write(CACHE_KEY, data, expires_in: RETRY_TTL)
      end
      data
    end

    def fetch_remote
      uri = URI(url)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        http.get(uri.request_uri, { "Accept" => "application/json", "User-Agent" => "omarchy-themes-site" })
      end
      raise Error, "catalog fetch failed: HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    rescue StandardError => e
      Rails.logger.warn("[catalog] fetch failed: #{e.class}: #{e.message}")
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
  def find!(slug) = find(slug) || raise(NotFound, "No theme #{slug.inspect}")
  def any_featured? = @themes.any?(&:featured?)
  def artists = @themes.map(&:artist_login).uniq

  # One row per artist, ranked by themes published, ties broken by total stars.
  def artist_stats
    @artist_stats ||= @themes.group_by(&:artist_login).map { |login, themes|
      { login: login, url: themes.first.artist_url, count: themes.size, stars: themes.sum(&:stars) }
    }.sort_by { |a| [ -a[:count], -a[:stars], a[:login].downcase ] }
      .each_with_index.map { |a, i| a.merge(rank: i + 1) }
  end

  def by_artist(login) = @themes.select { |t| t.artist_login.casecmp?(login) }
  def new_themes = @themes.select(&:new?)
  def dark = @themes.select(&:dark?)
  def light = @themes.select(&:light?)
end
