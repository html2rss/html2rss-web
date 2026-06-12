# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 429 error used when client hits rate limits.
    class TooManyRequestsError < HttpError
      DEFAULT_MESSAGE = 'Too many requests'
      STATUS = 429
      CODE = 'TOO_MANY_REQUESTS'
    end
  end
end
