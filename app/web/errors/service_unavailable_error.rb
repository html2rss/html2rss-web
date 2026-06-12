# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 503 error used when the server is temporarily overloaded or down.
    class ServiceUnavailableError < HttpError
      DEFAULT_MESSAGE = 'Service unavailable'
      STATUS = 503
      CODE = 'SERVICE_UNAVAILABLE'
    end
  end
end
