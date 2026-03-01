# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Utility for normalizing cache TTL values.
    module CacheTtl
      DEFAULT_SECONDS = 3600

      class << self
        # Converts feed-provided minutes to seconds with a safe default fallback.
        #
        # @param value [Object] TTL in minutes-like form.
        # @param default [Integer] seconds used when value is missing/invalid.
        # @return [Integer] positive cache TTL in seconds.
        def seconds_from_minutes(value, default: DEFAULT_SECONDS)
          minutes = value.to_i
          return default unless minutes.positive?

          minutes * 60
        end
      end
    end
  end
end
