# frozen_string_literal: true

require 'time'

module Html2rss
  module Web
    ##
    # Collection of methods which set HTTP Caching related headers in the response.
    module HttpCache
      class << self
        ##
        # Sets Expires and Cache-Control headers to cache for `seconds`.
        # @param response [Hash]
        # @param seconds [Integer]
        # @param cache_control [String, nil]
        # @return [void]
        def expires(response, seconds, cache_control: nil)
          expires_now(response) and return if seconds <= 0

          response['Expires'] = (Time.now + seconds).httpdate

          cache_value = "max-age=#{seconds}"
          cache_value += ",#{cache_control}" if cache_control
          response['Cache-Control'] = cache_value
        end

        ##
        # Sets Expires and Cache-Control headers to invalidate existing cache and
        # prevent caching.
        # @param response [Hash]
        # @return [void]
        def expires_now(response)
          response['Expires'] = '0'
          response['Cache-Control'] = 'private,max-age=0,no-cache,no-store,must-revalidate'
        end

        # @param response [Hash]
        # @param fields [Array<String>]
        # @return [void]
        def vary(response, *fields)
          existing = response['Vary'].to_s.split(',').map(&:strip).reject(&:empty?)
          response['Vary'] = (existing + fields).uniq.join(', ')
        end
      end
    end
  end
end
