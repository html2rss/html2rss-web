# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Request-scoped response target metadata used by routing and error handling.
    module RequestTarget
      ENV_KEY = 'html2rss.request_target'

      API = :api
      FEED = :feed

      class << self
        # @param request [#env]
        # @param target [Symbol]
        # @return [Symbol] assigned target.
        def mark!(request, target)
          request.env[ENV_KEY] = target
        end

        # @param request [#env]
        # @return [Symbol, nil] request target selected by the router.
        def current(request)
          request.env[ENV_KEY]
        end

        # @param request [#env]
        # @return [Boolean]
        def api?(request)
          current(request) == API
        end

        # @param request [#env]
        # @return [Boolean]
        def feed?(request)
          current(request) == FEED
        end
      end
    end
  end
end
