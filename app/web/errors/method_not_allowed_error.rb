# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 405 error used when the route does not support the request verb.
    class MethodNotAllowedError < HttpError
      DEFAULT_MESSAGE = 'Method Not Allowed'
      STATUS = 405
      CODE = 'METHOD_NOT_ALLOWED'
    end
  end
end
