# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 404 error used when a resource cannot be found.
    class NotFoundError < HttpError
      DEFAULT_MESSAGE = 'Not Found'
      STATUS = 404
      CODE = 'NOT_FOUND'
    end
  end
end
