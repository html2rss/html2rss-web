# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # HTTP 403 error raised when feed creation is disabled by instance policy.
    class AutoSourceDisabledError < ForbiddenError
      DEFAULT_MESSAGE = 'Auto source feature is disabled'
    end
  end
end
