# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module Refine
          ##
          # Authentication, feature gating and URL admission shared by refine endpoints.
          module Access
            class << self
              ##
              # Authenticates before checking flags so anonymous callers cannot discover
              # disabled refine capabilities.
              #
              # @param request [Rack::Request]
              # @param live_fetch [Boolean] whether the endpoint fetches the page
              # @return [Hash] authenticated account
              # @raise [Html2rss::Web::UnauthorizedError, Html2rss::Web::ForbiddenError]
              def ensure_allowed!(request, live_fetch: false)
                account = Auth.authenticate(request) or raise UnauthorizedError, 'Authentication required'
                raise ForbiddenError, 'Refine is disabled' unless Flags.refine_enabled?
                raise AutoSourceDisabledError if live_fetch && !Flags.auto_source_enabled?

                account
              end

              ##
              # @param raw_url [Object]
              # @param account [Hash]
              # @return [String] canonical page URL the account may reach
              # @raise [Html2rss::Web::BadRequestError, Html2rss::Web::ForbiddenError]
              def page_url!(raw_url, account)
                page_url(raw_url, account) or raise BadRequestError, 'URL parameter is required'
              end

              ##
              # @param raw_url [Object]
              # @param account [Hash]
              # @return [String, nil] canonical page URL, nil when none was sent
              # @raise [Html2rss::Web::BadRequestError, Html2rss::Web::ForbiddenError] when present but unusable
              def page_url(raw_url, account)
                stripped = raw_url.to_s.strip
                return if stripped.empty?

                url = UrlValidator.canonical_url(stripped) or raise BadRequestError, 'Invalid URL format'
                raise ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(account, url)

                url
              end
            end
          end
        end
      end
    end
  end
end
