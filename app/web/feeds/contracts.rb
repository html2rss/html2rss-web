# frozen_string_literal: true

require 'cgi'

module Html2rss
  module Web
    module Feeds
      ##
      # Immutable contracts used across feed request resolution, generation, and rendering.
      module Contracts
        ##
        # Request-edge contract for feed rendering.
        Request = Data.define(:target_kind, :feed_name, :token, :params) do
          class << self
            # Builds a normalized feed request from Rack request and route parameters.
            #
            # @param request [Rack::Request]
            # @param target_kind [Symbol]
            # @param identifier [String]
            # @return [Html2rss::Web::Feeds::Contracts::Request]
            def from_rack_request(request, target_kind:, identifier:)
              clean = FormatNegotiation.strip_known_extension(identifier)
              normalized = target_kind == :token ? CGI.unescape(clean) : clean

              new(
                target_kind:,
                feed_name: target_kind == :static ? normalized : nil,
                token: target_kind == :token ? normalized : nil,
                params: request.params.to_h
              )
            end
          end
        end

        ##
        # Normalized source inputs for shared feed generation.
        #
        # +feed_name+, +directory_defaults+, and +request_params+ support
        # directory-path {LastResults} recording for static feeds. Token sources
        # use +feed_name+ nil and empty defaults/params bags.
        ResolvedSource = Data.define(
          :source_kind,
          :cache_identity,
          :generator_input,
          :ttl_seconds,
          :url,
          :strategy,
          :feed_name,
          :directory_defaults,
          :request_params
        )

        ##
        # Normalized feed payload consumed by renderers and HTTP responders.
        #
        # @!attribute [r] feed
        #   @return [Html2rss::FeedResult, nil]
        RenderPayload = Data.define(:feed, :site_title, :url)

        ##
        # Shared feed-serving result: gem payload plus web status / {ErrorClassifier::Decision}.
        #
        # Non-ok results require +decision+ (sole owner of HTTP status and client message).
        # +diagnostics+ owns strategy attempts / transport telemetry.
        # +error_message+ is internal observability only.
        RenderResult = Data.define(:status, :payload, :ttl_seconds, :cache_key, :decision, :error_message,
                                   :empty_reason, :diagnostics) do
          class << self
            ##
            # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
            alias_method :__new, :new
            private :__new

            # Defaults keep existing keyword call sites stable when optional fields are absent.
            # Non-ok status requires +decision+ or raises ArgumentError.
            #
            # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
            def new(**)
              result = __new(
                payload: nil,
                decision: nil,
                error_message: nil,
                empty_reason: nil,
                diagnostics: ErrorClassifier::Diagnostics.empty,
                **
              )
              return result if result.status == :ok || result.decision

              raise ArgumentError, 'non-ok RenderResult requires decision'
            end
          end

          # @return [Integer]
          def http_status
            return 200 if status == :ok

            decision.status
          end

          # @return [String]
          def client_message
            decision.message
          end
        end
      end
    end
  end
end
