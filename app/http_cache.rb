# frozen_string_literal: true

require 'time'

##
# Collection of methods which set HTTP Caching related headers in the response.
module HttpCache
  module_function

  ##
  # Sets Expires and Cache-Control headers to cache for `seconds`.
  def expires(response, seconds, cache_control: nil)
    response['Expires'] = (Time.now + seconds).httpdate

    response['Cache-Control'] = if cache_control
                                  "max-age=#{seconds},#{cache_control}"
                                else
                                  "max-age=#{seconds}"
                                end
  end

  ##
  # Sets Expires and Cache-Control headers to invalidate existing cache and
  # prevent caching.
  def expires_now(response)
    response['Expires'] = '0'
    response['Cache-Control'] = 'private,max-age=0,no-cache,no-store,must-revalidate'
  end
end
