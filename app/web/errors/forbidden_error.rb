# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 403 error used when access is denied.
    class ForbiddenError < HttpError
      DEFAULT_MESSAGE = 'Forbidden'
      STATUS = 403
      CODE = 'FORBIDDEN'
    end
  end
end
