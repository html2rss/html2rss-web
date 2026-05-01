# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Request-scoped response target metadata used by routing and error handling.
    module RequestTarget
      ENV_KEY = 'html2rss.request_target'

      API = :api
      FEED = :feed
    end
  end
end
