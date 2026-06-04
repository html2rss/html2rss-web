# frozen_string_literal: true

require 'dry-validation'

module Html2rss
  class Config
    # Validates the configuration hash using Dry::Validation.
    # The configuration options adhere to the documented schema in README.md.
    class Validator < Dry::Validation::Contract # rubocop:disable Metrics/ClassLength
      # URI format used for channel URL validation.
      URI_REGEXP = Url::URI_REGEXP
      # Allowed stylesheet MIME types.
      STYLESHEET_TYPES = RssBuilder::Stylesheet::TYPES
      # Optional language/region format (`en` or `en-US`).
      LANGUAGE_FORMAT_REGEX = /\A[a-z]{2}(-[A-Z]{2})?\z/
      # Baseline strategy enum exported in static schema artifacts.
      BASE_STRATEGY_OPTIONS = ([:auto] + Html2rss::RequestService.strategy_names.map(&:to_sym)).uniq.freeze

      # Contract for the top-level `channel` section.
      ChannelConfig = Dry::Schema.Params do
        required(:url).filled(:string, format?: URI_REGEXP)
        optional(:title).maybe(:string)
        optional(:description).maybe(:string)
        optional(:language).maybe(:string, format?: LANGUAGE_FORMAT_REGEX)
        optional(:ttl).maybe(:integer, gt?: 0)
        optional(:time_zone).maybe(:string)
      end

      # Contract for a stylesheet entry in `stylesheets`.
      StylesheetConfig = Dry::Schema.Params do
        required(:href).filled(:string)
        required(:type).filled(:string, included_in?: STYLESHEET_TYPES)
        optional(:media).maybe(:string)
      end

      # Contract for Browserless click-preload options.
      BrowserlessPreloadClickSelectorConfig = Dry::Schema.Params do
        required(:selector).filled(:string)
        optional(:max_clicks).filled(:integer, gt?: 0)
        optional(:wait_after_ms).filled(:integer, gteq?: 0)
      end

      # Contract for Browserless scroll-preload options.
      BrowserlessPreloadScrollConfig = Dry::Schema.Params do
        optional(:iterations).filled(:integer, gt?: 0)
        optional(:wait_after_ms).filled(:integer, gteq?: 0)
      end

      # Contract for Browserless preload orchestration options.
      BrowserlessPreloadConfig = Dry::Schema.Params do
        optional(:wait_after_ms).filled(:integer, gteq?: 0)
        optional(:click_selectors).array(BrowserlessPreloadClickSelectorConfig)
        optional(:scroll_down).hash(BrowserlessPreloadScrollConfig)
      end

      # Contract for Browserless-specific request options.
      BrowserlessRequestConfig = Dry::Schema.Params do
        optional(:preload).hash(BrowserlessPreloadConfig)
      end

      # Contract for Botasaurus-specific request options.
      BotasaurusRequestConfig = Dry::Schema.Params do
        config.validate_keys = true

        optional(:navigation_mode).filled(:string, included_in?: %w[auto get google_get google_get_bypass])
        optional(:max_retries).filled(:integer, gteq?: 0, lteq?: 3)
        optional(:wait_for_selector).maybe(:string)
        optional(:wait_timeout_seconds).filled(:integer, gt?: 0)
        optional(:block_images).filled(:bool)
        optional(:block_images_and_css).filled(:bool)
        optional(:wait_for_complete_page_load).filled(:bool)
        optional(:headless).filled(:bool)
        optional(:proxy).filled(:string)
        optional(:user_agent).filled(:string)
        optional(:window_size).value(:array, min_size?: 2, max_size?: 2).each(:integer, gt?: 0)
        optional(:lang).filled(:string)
      end

      # Contract for the top-level `request` section.
      RequestConfig = Dry::Schema.Params do
        optional(:max_redirects).filled(:integer, gteq?: 0)
        optional(:max_requests).filled(:integer, gt?: 0)
        optional(:browserless).hash(BrowserlessRequestConfig)
        optional(:botasaurus).hash(BotasaurusRequestConfig)
      end

      params do
        optional(:strategy).filled(:symbol)
        required(:channel).hash(ChannelConfig)
        optional(:headers).hash
        optional(:stylesheets).array(StylesheetConfig)
        optional(:auto_source).hash(AutoSource::Config)
        optional(:selectors).hash
        optional(:dynamic_params_error).maybe(:string)
        optional(:request).hash(RequestConfig)
      end

      rule(:headers) do
        value&.each do |key, header_value|
          unless header_value.is_a?(String)
            key([:headers, key]).failure("must be a String, but got #{header_value.class}")
          end
        end
      end

      rule(:dynamic_params_error) do
        base.failure(value) if value
      end

      rule(:strategy) do
        next if value.nil?
        next if value == :auto || Html2rss::RequestService.strategy_registered?(value)

        key.failure("must be one of: #{BASE_STRATEGY_OPTIONS.join(', ')}")
      end

      # Ensure at least one of :selectors or :auto_source is present.
      rule(:selectors, :auto_source) do
        unless values.key?(:selectors) || values.key?(:auto_source)
          base.failure("Configuration must include at least 'selectors' or 'auto_source'")
        end
      end

      rule(:selectors) do
        next unless value

        errors = Html2rss::Selectors::Config.call(value).errors
        errors.each { |error| key(:selectors).failure(error.text) } unless errors.empty?
      end

      # URL validation delegated to Url class
      rule(:channel) do
        next unless values[:channel]&.key?(:url)

        url_string = values[:channel][:url]
        next if url_string.nil? || url_string.empty?

        begin
          Html2rss::Url.for_channel(url_string)
        rescue ArgumentError => error
          key(%i[channel url]).failure(error.message)
        end
      end
    end
  end
end
