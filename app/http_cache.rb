# frozen_string_literal: true

require 'time'

module App
  ##
  # Collection of methods which set HTTP Caching related headers in the response.
  module HttpCache
    module_function

    ##
    # Sets Expires and Cache-Control headers to cache for `seconds`.
    # @param response [Hash]
    # @param seconds [Integer]
    # @param cache_control [String, nil]
    def expires(response, seconds, cache_control: nil)
      response['Expires'] = (Time.now + seconds).httpdate

      cache_value = "max-age=#{seconds}"
      cache_value += ",#{cache_control}" if cache_control
      response['Cache-Control'] = cache_value
    end

    ##
    # Sets Expires and Cache-Control headers to invalidate existing cache and
    # prevent caching.
    # @param response [Hash]
    def expires_now(response)
      response['Expires'] = '0'
      response['Cache-Control'] = 'private,max-age=0,no-cache,no-store,must-revalidate'
    end
  end
end
