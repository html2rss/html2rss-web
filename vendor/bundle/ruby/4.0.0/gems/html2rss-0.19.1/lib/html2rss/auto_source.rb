# frozen_string_literal: true

require 'parallel'
require 'dry-validation'

module Html2rss
  ##
  # The AutoSource class automatically extracts articles from a given URL by
  # utilizing a collection of Scrapers. These scrapers analyze and
  # parse popular structured data formats—such as schema, microdata, and
  # open graph—to identify and compile article elements into unified articles.
  #
  # Scrapers supporting plain HTML are also available for sites without structured data,
  # though results may vary based on page markup.
  #
  # @see Html2rss::AutoSource::Scraper::Schema
  # @see Html2rss::AutoSource::Scraper::SemanticHtml
  # @see Html2rss::AutoSource::Scraper::Html
  class AutoSource
    # Default auto-source configuration shipped for scraper and cleanup behavior.
    DEFAULT_CONFIG = {
      scraper: {
        wordpress_api: {
          enabled: true
        },
        schema: {
          enabled: true
        },
        microdata: {
          enabled: true
        },
        json_state: {
          enabled: true
        },
        semantic_html: {
          enabled: true
        },
        html: {
          enabled: true,
          minimum_selector_frequency: Scraper::Html::DEFAULT_MINIMUM_SELECTOR_FREQUENCY,
          use_top_selectors: Scraper::Html::DEFAULT_USE_TOP_SELECTORS
        }
      },
      cleanup: Cleanup::DEFAULT_CONFIG
    }.freeze

    SCRAPER_CONFIG = proc do
      optional(:wordpress_api).hash do
        optional(:enabled).filled(:bool)
      end
      optional(:schema).hash do
        optional(:enabled).filled(:bool)
      end
      optional(:microdata).hash do
        optional(:enabled).filled(:bool)
      end
      optional(:json_state).hash do
        optional(:enabled).filled(:bool)
      end
      optional(:semantic_html).hash do
        optional(:enabled).filled(:bool)
      end
      optional(:html).hash do
        optional(:enabled).filled(:bool)
        optional(:minimum_selector_frequency).filled(:integer, gt?: 0)
        optional(:use_top_selectors).filled(:integer, gt?: 0)
      end
    end.freeze
    private_constant :SCRAPER_CONFIG

    # Runtime schema used to validate auto-source config values.
    Config = Dry::Schema.Params do
      optional(:scraper).hash(&SCRAPER_CONFIG)

      optional(:cleanup).hash do
        optional(:keep_different_domain).filled(:bool)
        optional(:min_words_title).filled(:integer, gt?: 0)
      end
    end

    ##
    # @param response [Html2rss::RequestService::Response] initial page response
    # @param opts [Hash] validated auto-source options
    # @param request_session [Html2rss::RequestSession, nil] shared request session for follow-up fetches
    # @option opts [Hash] :scraper scraper configuration map
    # @option opts [Hash] :cleanup cleanup configuration map
    # @return [void]
    def initialize(response, opts = DEFAULT_CONFIG, request_session: nil)
      @parsed_body = response.parsed_body
      @url = response.url
      @opts = opts
      @request_session = request_session
    end

    ##
    # Extracts article candidates by selecting every scraper that can explain the
    # page shape, running those scrapers, and normalizing the resulting hashes
    # into `RssBuilder::Article` objects.
    #
    # The contributor-facing flow is:
    # 1. choose scraper instances that match the page
    # 2. let each scraper collect its own candidates
    # 3. clean and deduplicate the merged article list
    #
    # Scrapers with expensive precomputation, such as `SemanticHtml`, keep that
    # state on the instance so detection and extraction can reuse the same work.
    #
    # @return [Array<Html2rss::RssBuilder::Article>] extracted articles
    def articles
      @articles ||= extract_articles
    rescue Html2rss::AutoSource::Scraper::NoScraperFound => error
      Log.warn "#{self.class}: no scraper matched #{url} (#{error.message})"
      []
    end

    private

    attr_reader :url, :parsed_body, :request_session

    def extract_articles
      scraper_instances = Scraper.instances_for(parsed_body, url:, request_session:, opts: @opts[:scraper])
      return [] if scraper_instances.empty?

      # Scrapers are instantiated and run in parallel threads. Implementations
      # must avoid shared mutable state, treat request_session calls as
      # concurrency-safe from the scraper side, and return no articles when a
      # follow-up would be unsafe or unsupported.
      articles = Parallel.flat_map(scraper_instances, in_threads: thread_count_for(scraper_instances)) do |instance|
        run_scraper(instance)
      end
      Cleanup.call(articles, url:, **cleanup_options)
    end

    def run_scraper(instance)
      instance.each.map do |article_hash|
        RssBuilder::Article.new(**article_hash, scraper: instance.class)
      end
    end

    def cleanup_options
      @opts.fetch(:cleanup, {})
    end

    def thread_count_for(scrapers)
      count = [scrapers.size, Parallel.processor_count].min
      count.zero? ? 1 : count
    end
  end
end
