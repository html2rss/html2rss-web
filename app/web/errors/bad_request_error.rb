# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 400 error used for invalid client input.
    class BadRequestError < HttpError
      DEFAULT_MESSAGE = 'Bad Request'
      STATUS = 400
      CODE = 'BAD_REQUEST'
    end
  end
end
