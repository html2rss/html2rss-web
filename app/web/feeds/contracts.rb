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
                                   :error_class, :empty_reason, :diagnostics, :cache_hit) do
          # Optional fields default when absent; non-ok status requires +decision+.
          #
          # @param payload [RenderPayload, nil]
          # @param decision [ErrorClassifier::Decision, nil]
          # @param error_message [String, nil]
          # @param error_class [String, nil]
          # @param empty_reason [String, nil]
          # @param diagnostics [ErrorClassifier::Diagnostics]
          # @param cache_hit [Boolean]
          # @raise [ArgumentError] when a non-ok result has no decision
          def initialize(payload: nil, decision: nil, error_message: nil, error_class: nil, empty_reason: nil, # rubocop:disable Metrics/ParameterLists
                         diagnostics: ErrorClassifier::Diagnostics.empty, cache_hit: false, **)
            super
            raise ArgumentError, 'non-ok RenderResult requires decision' unless status == :ok || decision
          end

          # @return [Integer]
          def http_status = status == :ok ? 200 : decision.status

          # @return [String]
          def client_message = decision.message

          # @return [Boolean]
          def cacheable? = decision.nil? || decision.cacheable
        end
      end
    end
  end
end
