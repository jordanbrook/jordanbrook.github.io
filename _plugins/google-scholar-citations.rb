require "active_support/all"
require "net/http"
require "nokogiri"
require "uri"
require "yaml"

module Helpers
  extend ActiveSupport::NumberHelper
end

module Jekyll
  class GoogleScholarCitationsTag < Liquid::Tag
    CITATIONS = {}
    CACHE_PATH = File.expand_path("../_data/google-scholar-citations.yml", __dir__)
    USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "\
                 "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36".freeze

    def initialize(tag_name, params, tokens)
      super
      splitted = params.split(/\s+/).map(&:strip)
      @scholar_id_markup = splitted[0]
      @article_id_markup = splitted[1]
    end

    def render(context)
      article_id = evaluate_markup(context, @article_id_markup)
      scholar_id = evaluate_markup(context, @scholar_id_markup)

      return "N/A" if article_id.blank? || scholar_id.blank?

      cache_key = "#{scholar_id}:#{article_id}"
      return self.class.citations[cache_key] if self.class.citations.key?(cache_key)

      citation_count = fetch_citation_count(scholar_id, article_id)
      citation_count = cached_citation_count(cache_key, article_id) if citation_count.nil?
      citation_count ||= "N/A"

      self.class.citations[cache_key] = citation_count
      citation_count.to_s
    end

    private

    def evaluate_markup(context, markup)
      context.evaluate(Liquid::Expression.parse(markup))
    rescue StandardError
      context[markup.to_s.strip]
    end

    def fetch_citation_count(scholar_id, article_id)
      article_url = citation_url(scholar_id, article_id)
      last_error = nil

      3.times do |attempt|
        sleep(1 + attempt) if attempt.positive?

        begin
          response_body = http_get(article_url)
          count = extract_citation_count(response_body)
          return format_count(count) unless count.nil?
        rescue StandardError => e
          last_error = e
        end
      end

      if last_error
        puts "Error fetching citation count for #{article_id}: #{last_error.class} - #{last_error.message}"
      else
        puts "Error fetching citation count for #{article_id}: citation count not found in response"
      end

      nil
    end

    def citation_url(scholar_id, article_id)
      "https://scholar.google.com/citations?view_op=view_citation&hl=en&user=#{scholar_id}&citation_for_view=#{scholar_id}:#{article_id}"
    end

    def http_get(url, limit = 5)
      raise "Too many redirects" if limit <= 0

      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      request["Accept-Language"] = "en-US,en;q=0.9"
      request["Cache-Control"] = "no-cache"
      request["Pragma"] = "no-cache"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        next_url = URI.join(url, response["location"]).to_s
        http_get(next_url, limit - 1)
      else
        raise "Unexpected HTTP response #{response.code}"
      end
    end

    def extract_citation_count(response_body)
      doc = Nokogiri::HTML(response_body)
      description_meta = doc.css('meta[name="description"], meta[property="og:description"]')

      description_meta.each do |meta_tag|
        count = parse_citation_count(meta_tag["content"])
        return count unless count.nil?
      end

      return 0 unless description_meta.empty?

      parse_citation_count(response_body)
    end

    def parse_citation_count(text)
      return nil if text.blank?

      matches = text.match(/Cited by (\d[\d,]*)/)
      return nil if matches.nil?

      matches[1].delete(",").to_i
    end

    def cached_citation_count(cache_key, article_id)
      cached = self.class.cache[cache_key]
      cached = self.class.cache[article_id] if cached.nil?
      return nil if cached.nil?

      cached.to_s
    end

    def format_count(citation_count)
      Helpers.number_to_human(
        citation_count,
        format: "%n%u",
        precision: 2,
        units: {
          thousand: "K",
          million: "M",
          billion: "B"
        }
      )
    end

    class << self
      def citations
        CITATIONS
      end

      def cache
        @cache ||= load_cache
      end

      def load_cache
        return {} unless File.exist?(CACHE_PATH)

        YAML.safe_load(File.read(CACHE_PATH), permitted_classes: [], aliases: false) || {}
      rescue StandardError => e
        puts "Error loading Google Scholar citation cache: #{e.class} - #{e.message}"
        {}
      end
    end
  end
end

Liquid::Template.register_tag("google_scholar_citations", Jekyll::GoogleScholarCitationsTag)
