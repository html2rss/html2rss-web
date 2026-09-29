# frozen_string_literal: true

require 'time'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Creates stable feed records from authenticated API requests.
        module CreateFeed
          FEED_ATTRIBUTE_KEYS = %i[id name url feed_token public_url json_public_url created_at updated_at].freeze
          ABSOLUTE_URL_REGEXP = %r{\A[a-z][a-z0-9+\-.]*://}i
          HOSTNAME_INPUT_REGEXP = %r{
            \A(localhost(?::\d+)?|(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?|(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?)
            (?:[/?#].*)?\z
          }ix

          # Gates an optional selectors object through {SelectorsDocument} before it is signed.
          # Absent keeps legacy tokens valid and keeps create on the automatic path, which the
          # studio flag does not gate. Present means the caller authored the selectors in the
          # studio, so the same kill switch the studio POSTs enforce applies here.
          #
          # @param request [Rack::Request]
          # @return [Html2rss::Web::SelectorsDocument, nil]
          # @raise [Html2rss::Web::ForbiddenError] when selectors are sent while the studio is disabled
          def self.selectors_for(request)
            raw = request_params(request)['selectors']
            return nil if raw.nil?

            raise Html2rss::Web::ForbiddenError, 'Studio is disabled' unless Flags.studio_enabled?

            SelectorsDocument.from_client({ selectors: raw })
          end
          private_class_method :selectors_for

          class << self
            # Creates a feed and returns a normalized API success payload.
            #
            # @param request [Rack::Request] HTTP request with auth context.
            # @return [Hash{Symbol=>Object}] API response payload.
            def call(request)
              account = require_account(request)
              params = build_create_params(request, account)
              feed_data = create_feed(params, account, request)
              emit_create(status: :success, details: { url: params.url })
              Response.success(response: request.response, status: 201,
                               data: { feed: feed_attributes(feed_data) }, meta: { created: true })
            rescue StandardError => error
              emit_create(status: :failure, details: { error_class: error.class.name, error_message: error.message })
              raise
            end

            private

            def require_account(request)
              Auth.authenticate(request) || raise(Html2rss::Web::UnauthorizedError, 'Authentication required')
            end

            def build_create_params(request, account)
              JsonBody.enforce_limit!(request)
              params = request_params(request)
              url = validated_url(params['url'], account)
              name = params['name'].to_s.strip
              name = nil if name.empty?
              FeedMetadata::CreateParams.new(url:, name:)
            end

            def request_params(request)
              return request.params unless json_request?(request)

              request.GET.merge(JsonBody.object(request))
            end

            def json_request?(request)
              request.env['CONTENT_TYPE'].to_s.include?('application/json')
            end

            # @param raw_url [String, nil]
            # @param account [Hash]
            # @return [String]
            def validated_url(raw_url, account)
              url = normalized_input_url(raw_url)
              raise Html2rss::Web::BadRequestError, 'URL parameter is required' if url.empty?

              url = UrlValidator.canonical_url(url)
              raise Html2rss::Web::BadRequestError, 'Invalid URL format' unless url
              raise Html2rss::Web::ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(
                account, url
              )

              url
            end

            # @param raw_url [String, nil]
            # @return [String]
            def normalized_input_url(raw_url)
              url = raw_url.to_s.strip
              return url if url.empty? || ABSOLUTE_URL_REGEXP.match?(url)
              return "https:#{url}" if url.start_with?('//')

              HOSTNAME_INPUT_REGEXP.match?(url) ? "https://#{url}" : url
            end

            # @param params [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            # @param account [Hash]
            # @param request [Rack::Request]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def create_feed(params, account, request)
              selectors = selectors_for(request)
              raise Html2rss::Web::AutoSourceDisabledError unless Flags.auto_source_enabled?

              feed_token = Auth.generate_feed_token(account[:username], params.url, selectors:)
              raise Html2rss::Web::InternalServerError, 'Failed to create feed' unless feed_token

              result = Feeds::Service.call(resolved_source_for(feed_token))
              ensure_extractable!(result)
              name = resolve_feed_name(params.name, result, params.url)
              FeedMetadata.build(account:, name:, url: params.url, feed_token:)
            end

            # @param requested_name [String, nil]
            # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
            # @param url [String]
            # @return [String]
            def resolve_feed_name(requested_name, result, url)
              return requested_name unless requested_name.to_s.empty?

              site_title = result.payload&.site_title
              return site_title unless site_title.to_s.empty?

              Feeds::ChannelTitle.for(url) || url.to_s
            end

            # @param feed_token [String]
            # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
            def resolved_source_for(feed_token)
              Feeds::SourceResolver.call(
                Feeds::Contracts::Request.new(target_kind: :token, feed_name: nil, token: feed_token, params: {})
              )
            end

            # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
            # @return [void]
            def ensure_extractable!(result)
              return if result.status == :ok

              raise ErrorClassifier::DecidedError, result.decision
            end

            # @param feed_data [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            # @return [Hash{Symbol=>Object}]
            def feed_attributes(feed_data)
              timestamp = Time.now.iso8601
              feed_data.to_h.merge(created_at: timestamp, updated_at: timestamp).slice(*FEED_ATTRIBUTE_KEYS)
            end

            # @param status [Symbol]
            # @param details [Hash{Symbol=>Object}]
            # @return [void]
            def emit_create(status:, details:)
              level = status == :success ? :info : :warn
              Observability.emit(event_name: 'feed.create', outcome: status.to_s, details:, level:)
            end
          end
        end
      end
    end
  end
end
