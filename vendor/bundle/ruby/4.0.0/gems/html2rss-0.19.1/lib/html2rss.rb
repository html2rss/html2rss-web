# frozen_string_literal: true

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect('cli' => 'CLI')
loader.setup

require 'logger'

##
# The Html2rss namespace.
module Html2rss
  ##
  # The logger instance.
  Log = Logger.new($stdout)

  Log.level = ENV.fetch('LOG_LEVEL', :warn).upcase.to_sym

  Log.formatter = proc do |severity, datetime, _progname, msg|
    "#{datetime} [#{severity}] #{msg}\n"
  end

  ##
  # Loads a feed configuration from YAML.
  #
  # @param file [String] path to the YAML file
  # @param feed_name [String, nil] optional feed name inside a multi-feed config
  # @return [Hash{Symbol => Object}] loaded configuration hash
  def self.config_from_yaml_file(file, feed_name = nil)
    Config.load_yaml(file, feed_name)
  end

  ##
  # Returns an RSS object generated from the provided configuration.
  #
  # @param raw_config [Hash{Symbol => Object}] feed configuration
  # @return [RSS::Rss] generated RSS feed
  def self.feed(raw_config)
    FeedPipeline.new(raw_config).to_rss
  end

  ##
  # Returns a JSONFeed 1.1 hash generated from the provided configuration.
  #
  # @param raw_config [Hash{Symbol => Object}] feed configuration
  # @return [Hash] JSONFeed-compliant hash
  def self.json_feed(raw_config)
    FeedPipeline.new(raw_config).to_json_feed
  end

  ##
  # Scrapes the provided URL and returns an RSS object.
  #
  # @param url [String] source page URL
  # @param strategy [Symbol] request strategy to use
  # @param items_selector [String, nil] optional selector hint for item extraction
  # @param max_redirects [Integer, nil] optional redirect limit override
  # @param max_requests [Integer, nil] optional request budget override
  # @return [RSS::Rss] generated RSS feed
  def self.auto_source(url, strategy: :auto, items_selector: nil, max_redirects: nil, max_requests: nil)
    feed(build_auto_source_config(url:, strategy:, items_selector:, max_redirects:, max_requests:))
  end

  ##
  # Scrapes the provided URL and returns a JSONFeed 1.1 hash.
  #
  # @param url [String] source page URL
  # @param strategy [Symbol] request strategy to use
  # @param items_selector [String, nil] optional selector hint for item extraction
  # @param max_redirects [Integer, nil] optional redirect limit override
  # @param max_requests [Integer, nil] optional request budget override
  # @return [Hash] JSONFeed-compliant hash
  def self.auto_json_feed(url, strategy: :auto, items_selector: nil, max_redirects: nil, max_requests: nil)
    json_feed(build_auto_source_config(url:, strategy:, items_selector:, max_redirects:, max_requests:))
  end

  class << self
    private

    def build_auto_source_config(url:, strategy:, items_selector:, max_redirects:, max_requests:)
      Config.auto_source_config(
        url:,
        items_selector:,
        request_controls: shortcut_request_controls(strategy:, max_redirects:, max_requests:)
      )
    end

    def shortcut_request_controls(strategy:, max_redirects:, max_requests:)
      RequestControls.new(
        strategy:,
        max_redirects:,
        max_requests:,
        explicit_keys: explicit_request_control_keys(strategy:, max_redirects:, max_requests:)
      )
    end

    def explicit_request_control_keys(strategy:, max_redirects:, max_requests:)
      keys = []
      keys << :strategy unless strategy.nil? || strategy == Config.default_strategy_name
      keys << :max_redirects unless max_redirects.nil?
      keys << :max_requests unless max_requests.nil?
      keys
    end
  end
end

loader.eager_load
