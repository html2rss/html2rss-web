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

          class << self
            # Creates a feed and returns a normalized API success payload.
            #
            # @param request [Rack::Request] HTTP request with auth context.
            # @return [Hash{Symbol=>Object}] API response payload.
            def call(request)
              params = nil
              account = require_account(request)
              params = Input.call(request, account)
              feed_data = create_feed(params, account)

              emit_create(status: :success, details: { url: params.url })
              Response.success(response: request.response, status: 201,
                               data: { feed: feed_attributes(feed_data) }, meta: { created: true })
            rescue StandardError => error
              emit_create(status: :failure, details: create_failure_details(error, params))
              raise
            end

            private

            def require_account(request)
              account = Auth.authenticate(request)
              raise UnauthorizedError, 'Authentication required' unless account

              account
            end

            # Extracts via {Feeds::Service} before minting so create and serve share one expansion path.
            #
            # @param params [Html2rss::Web::Api::V1::FeedMetadata::CreateParams]
            # @param account [Hash]
            # @return [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            def create_feed(params, account)
              raise AutoSourceDisabledError unless Flags.auto_source_enabled?

              feed_token = FeedToken.generate(account[:username], params.url)
              raise InternalServerError, 'Failed to create feed' unless feed_token

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

              raise ErrorClassifier::DecidedError.new(result.decision, diagnostics: result.diagnostics)
            end

            # @param feed_data [Html2rss::Web::Api::V1::FeedMetadata::Metadata]
            # @return [Hash{Symbol=>Object}]
            def feed_attributes(feed_data)
              timestamp = Time.now.iso8601
              feed_data.to_h.merge(created_at: timestamp, updated_at: timestamp).slice(*FEED_ATTRIBUTE_KEYS)
            end

            # @param error [StandardError]
            # @param params [Html2rss::Web::Api::V1::FeedMetadata::CreateParams, nil]
            # @return [Hash{Symbol=>Object}]
            def create_failure_details(error, params)
              {
                error_class: error.class.name,
                error_message: error.message,
                error_code: ErrorClassifier.classify(error).code,
                **ErrorClassifier::Diagnostics.from_error(error).to_h
              }.tap { |details| details[:url] = params.url if params }
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
