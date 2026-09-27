require "net/http"

# The published theme catalog. Fetched from the CDN and kept for a few minutes. When the CDN is
# unreachable the site keeps serving the last catalog it fetched; the snapshot in data/catalog.json
# is only for a process that has never reached the CDN (a cold boot during an outage, and tests).
#
# Every request reads the same built Catalog from process memory: nothing is copied, parsed or
# rebuilt per request, and an unchanged catalog is not downloaded again (the CDN answers 304).
# Catalogs are shared between threads, so they are never changed after they are built.
class Catalog
  TTL = 5.minutes
  # While serving a fallback, try the CDN again this soon.
  RETRY_TTL = 1.minute
  SNAPSHOT = Rails.root.join("data/catalog.json")

  Error = Class.new(StandardError)

  Entry = Data.define(:catalog, :expires_at) do
    def fresh? = expires_at > Catalog.clock
  end
  LOCK = Mutex.new

  class << self
    # When the kept catalog expires, one thread refreshes it and the others keep serving it
    # meanwhile, so no request waits on the CDN except the very first.
    def current
      entry = @entry
      return entry.catalog if entry&.fresh?

      if entry
        return entry.catalog unless LOCK.try_lock
        begin
          refresh
        ensure
          LOCK.unlock
        end
      else
        LOCK.synchronize { @entry&.catalog || refresh }
      end
    end

    def url
      Rails.configuration.x.catalog_url
    end

    # The snapshot can be weeks old and still list themes that have since left the catalog, so a
    # fetched copy, however stale, is the better fallback.
    def refresh
      fetched = url.present? ? fetch_remote : nil
      catalog = case fetched
      when :not_modified then @last_fetched
      when Hash then unchanged?(fetched) ? @last_fetched : new(fetched)
      end

      if catalog
        @last_fetched = catalog
        keep(catalog, TTL)
      else
        Rails.logger.warn("[catalog] serving the #{@last_fetched ? "last fetched catalog" : "snapshot"}") if url.present?
        keep(@last_fetched || new(snapshot), RETRY_TTL)
      end
    end

    # nil when the fetch failed, :not_modified when the CDN says the catalog is unchanged.
    def fetch_remote
      uri = URI(url)
      headers = { "Accept" => "application/json", "User-Agent" => "omarchy-themes-site" }
      headers["If-None-Match"] = @etag if @etag && @last_fetched
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        http.get(uri.request_uri, headers)
      end
      return :not_modified if res.is_a?(Net::HTTPNotModified)
      raise Error, "catalog fetch failed: HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)
      @etag = res["ETag"]
      data
    rescue StandardError => e
      Rails.logger.warn("[catalog] fetch failed: #{e.class}: #{e.message}")
      nil
    end

    def snapshot
      JSON.parse(File.read(SNAPSHOT))
    end

    # Forget everything kept in memory (tests).
    def reset!
      @entry = @last_fetched = @etag = nil
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    private

    def keep(catalog, ttl)
      @entry = Entry.new(catalog:, expires_at: clock + ttl.to_i)
      catalog
    end

    def unchanged?(data)
      @last_fetched&.generated_at.present? && data["generated_at"] &&
        @last_fetched.generated_at == Time.iso8601(data["generated_at"])
    end
  end

  attr_reader :generated_at, :schema_version

  # Everything derived from the themes is worked out here, once per catalog, and frozen: a built
  # catalog is shared by every request until the next one replaces it.
  def initialize(data)
    @schema_version = data["schema_version"]
    @generated_at = data["generated_at"] && Time.iso8601(data["generated_at"])
    @themes = data.fetch("themes", []).map { |t| Theme.new(t) }.freeze
    @by_slug = @themes.index_by(&:slug).freeze
    @by_artist = @themes.group_by { |t| t.artist_login.to_s.downcase }.transform_values(&:freeze).freeze
    @artists = @themes.map(&:artist_login).uniq.freeze
    @artist_stats = rank_artists.freeze
    @dark = @themes.select(&:dark?).freeze
    @light = @themes.select(&:light?).freeze
  end

  attr_reader :themes, :artists, :artist_stats, :dark, :light

  def size = @themes.size
  def find(slug) = @by_slug[slug]
  def find!(slug) = find(slug) || raise(NotFound, "No theme #{slug.inspect}")
  def any_featured? = @themes.any?(&:featured?)
  def by_artist(login) = @by_artist.fetch(login.to_s.downcase, [])
  def new_themes = @themes.select(&:new?)

  # The themes whose palettes look most like `theme`'s. Worked out per request rather than for
  # every pair up front, which would grow with the square of the catalog.
  def similar_to(theme, limit: 3)
    @themes.reject { |t| t.equal?(theme) }.min_by(limit) { |t| theme.palette_distance(t) }
  end

  private

  # One row per artist, ranked by themes published, ties broken by total stars.
  def rank_artists
    @themes.group_by(&:artist_login).map { |login, themes|
      { login: login, url: themes.first.artist_url, count: themes.size, stars: themes.sum(&:stars) }
    }.sort_by { |a| [ -a[:count], -a[:stars], a[:login].downcase ] }
      .each_with_index.map { |a, i| a.merge(rank: i + 1).freeze }
  end
end
