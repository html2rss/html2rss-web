# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 401 error used when authentication is required.
    class UnauthorizedError < HttpError
      DEFAULT_MESSAGE = 'Authentication required'
      STATUS = 401
      CODE = 'UNAUTHORIZED'
    end
  end
end
