# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Shared authentication, feature gating, and JSON parsing for studio requests.
        module StudioRequest
          class << self
            ##
            # Authenticates before checking feature flags so anonymous callers
            # cannot discover disabled studio capabilities.
            #
            # @param request [Rack::Request]
            # @param live_fetch [Boolean] whether the request needs automatic source fetching
            # @return [Hash] the authenticated account
            def ensure_allowed!(request, live_fetch: false)
              account = Auth.authenticate(request)
              raise UnauthorizedError, 'Authentication required' unless account
              raise ForbiddenError, 'Studio is disabled' unless Flags.studio_enabled?
              raise AutoSourceDisabledError if live_fetch && !Flags.auto_source_enabled?

              account
            end

            ##
            # Canonical page URL the account is allowed to reach.
            #
            # @param raw_url [Object]
            # @param account [Hash]
            # @return [String]
            def allowed_url(raw_url, account)
              stripped = raw_url.to_s.strip
              raise BadRequestError, 'URL parameter is required' if stripped.empty?

              require_allowed_url(stripped, account)
            end

            ##
            # Canonical page URL when the caller sent one.
            #
            # A blank value is absent. A present value that cannot be used raises.
            #
            # @param raw_url [Object]
            # @param account [Hash]
            # @return [String, nil]
            def page_url(raw_url, account)
              stripped = raw_url.to_s.strip
              return if stripped.empty?

              require_allowed_url(stripped, account)
            end

            ##
            # Parses a size-bounded JSON request body as an object.
            #
            # @param request [Rack::Request]
            # @return [Hash]
            # @see JsonBody.object
            def json_object(request)
              JsonBody.object(request)
            end

            private

            # @param stripped [String]
            # @param account [Hash]
            # @return [String]
            def require_allowed_url(stripped, account)
              url = UrlValidator.canonical_url(stripped)
              raise BadRequestError, 'Invalid URL format' unless url
              raise ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(account, url)

              url
            end
          end
        end
      end
    end
  end
end
