# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'thor'

##
# The Html2rss namespace / command line interface.
module Html2rss
  ##
  # The Html2rss command line interface.
  class CLI < Thor # rubocop:disable Metrics/ClassLength
    check_unknown_options!
    # Ordered fallback chain attempted by auto strategy.
    #
    # @return [Array<Symbol>]
    AUTO_FALLBACK_CHAIN = Html2rss::FeedPipeline::AutoFallback::CHAIN.freeze
    # Supported CLI strategy option values.
    #
    # @return [Array<String>]
    STRATEGY_OPTION_ENUM = (['auto'] + Html2rss::RequestService.strategy_names).uniq.freeze
    # User-facing strategy help text that reflects the current fallback chain.
    #
    # @return [String]
    STRATEGY_OPTION_DESC = [
      'Optional request strategy (defaults to auto; auto tries',
      "#{AUTO_FALLBACK_CHAIN.join(' -> ')})"
    ].join(' ').freeze

    # @return [Boolean] whether Thor should terminate process on command failures
    def self.exit_on_failure?
      true
    end

    desc 'feed YAML_FILE [feed_name]', 'Print RSS built from the YAML_FILE file to stdout'
    method_option :params,
                  type: :hash,
                  optional: true,
                  required: false,
                  default: {}
    method_option :strategy,
                  type: :string,
                  desc: STRATEGY_OPTION_DESC,
                  enum: STRATEGY_OPTION_ENUM
    method_option :max_redirects,
                  type: :numeric,
                  desc: 'Maximum redirects to follow per request'
    method_option :max_requests,
                  type: :numeric,
                  desc: 'Maximum requests to allow for this feed build'
    # @param yaml_file [String] path to YAML config
    # @param feed_name [String, nil] optional named feed in multi-feed config
    # @return [void]
    def feed(yaml_file, feed_name = nil)
      config = Html2rss.config_from_yaml_file(yaml_file, feed_name)
      config[:params] = options[:params] || {}
      apply_runtime_request_overrides!(config)

      puts(execute_feed { Html2rss.feed(config) })
    end

    desc 'auto [URL]', 'Automatically sources an RSS feed from the URL'
    method_option :strategy,
                  type: :string,
                  desc: STRATEGY_OPTION_DESC,
                  enum: STRATEGY_OPTION_ENUM
    method_option :format,
                  type: :string,
                  desc: 'Output format for the auto-sourced feed',
                  enum: %w[rss jsonfeed],
                  default: 'rss'
    method_option :items_selector, type: :string, desc: 'CSS selector for items (will be enhanced) (optional)'
    method_option :max_redirects,
                  type: :numeric,
                  desc: 'Maximum redirects to follow per request'
    method_option :max_requests,
                  type: :numeric,
                  desc: 'Maximum requests to allow for this feed build'
    # @param url [String] source page URL for auto discovery
    # @return [void]
    def auto(url) # rubocop:disable Metrics/MethodLength
      format = options.fetch(:format, 'rss')
      source_method = format == 'jsonfeed' ? Html2rss.method(:auto_json_feed) : Html2rss.method(:auto_source)

      result = execute_feed do
        source_method.call(
          url,
          strategy: current_strategy,
          items_selector: options[:items_selector],
          max_redirects: options[:max_redirects],
          max_requests: options[:max_requests]
        )
      end

      puts(format == 'jsonfeed' ? JSON.pretty_generate(result) : result)
    end

    desc 'schema', 'Print the exported config JSON Schema'
    method_option :pretty,
                  type: :boolean,
                  desc: 'Pretty-print the schema JSON',
                  default: true
    method_option :write,
                  type: :string,
                  desc: 'Write the schema JSON to the given file path'
    ##
    # Prints or writes the exported configuration JSON Schema.
    #
    # @return [void]
    def schema
      schema_json = Html2rss::Config.json_schema_json(pretty: options.fetch(:pretty, true))

      if options[:write]
        FileUtils.mkdir_p(File.dirname(options[:write]))
        File.write(options[:write], "#{schema_json}\n")
        puts options[:write]
        return
      end

      puts schema_json
    end

    desc 'validate YAML_FILE [feed_name]', 'Validate a YAML config with the runtime validator'
    method_option :params,
                  type: :hash,
                  optional: true,
                  required: false,
                  default: {}
    ##
    # Validates a YAML config and prints the result.
    #
    # @param yaml_file [String] the YAML file to validate
    # @param feed_name [String, nil] optional feed name for multi-feed files
    # @return [void]
    def validate(yaml_file, feed_name = nil)
      result = Html2rss::Config.validate_yaml(yaml_file, feed_name, params: options[:params] || {})

      raise Thor::Error, "Invalid configuration: #{result.errors.to_h}" unless result.success?

      puts 'Configuration is valid'
    end

    private

    def apply_runtime_request_overrides!(config)
      clear_blank_request_overrides!(config)
      request_controls.apply_to(config)
    end

    def clear_blank_request_overrides!(config)
      config.delete(:strategy) if config[:strategy].nil?

      request_config = config[:request]
      return unless request_config.is_a?(Hash)

      %i[max_redirects max_requests].each do |key|
        request_config.delete(key) if request_config[key].nil?
      end
      config.delete(:request) if request_config.empty?
    end

    def request_controls
      Html2rss::RequestControls.new(
        strategy: options[:strategy]&.to_sym,
        max_redirects: options[:max_redirects],
        max_requests: options[:max_requests],
        explicit_keys: explicit_request_control_keys
      )
    end

    def explicit_request_control_keys
      keys = []
      keys << :strategy if options[:strategy]
      keys << :max_redirects unless options[:max_redirects].nil?
      keys << :max_requests unless options[:max_requests].nil?
      keys
    end

    def current_strategy
      options[:strategy]&.to_sym || :auto
    end

    def current_max_redirects
      options.fetch(:max_redirects, Html2rss::RequestService::Policy::DEFAULTS[:max_redirects])
    end

    def current_max_requests
      options.fetch(:max_requests, Html2rss::RequestService::Policy::DEFAULTS[:max_requests])
    end

    def suggested_max_redirects
      current_max_redirects + 1
    end

    def suggested_max_requests
      current_max_requests + 1
    end

    def execute_feed # rubocop:disable Metrics/MethodLength
      yield
    rescue Faraday::FollowRedirects::RedirectLimitReached => error
      raise Thor::Error,
            "#{error.message}. retry with --max-redirects #{suggested_max_redirects} or use the final URL directly."
    rescue Html2rss::RequestService::RequestBudgetExceeded => error
      raise Thor::Error,
            "#{error.message}. retry with --max-requests #{suggested_max_requests} " \
            'or increase request.max_requests in the config.'
    rescue Html2rss::RequestService::BrowserlessConfigurationError,
           Html2rss::RequestService::BrowserlessConnectionFailed,
           Html2rss::RequestService::BotasaurusConfigurationError,
           Html2rss::RequestService::BotasaurusConnectionFailed,
           Html2rss::RequestService::BlockedSurfaceDetected,
           Html2rss::NoFeedItemsExtracted => error
      raise Thor::Error, error.message
    end
  end
end
