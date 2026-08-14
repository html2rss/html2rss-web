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
        ResolvedSource = Data.define(:source_kind, :cache_identity, :generator_input, :ttl_seconds, :url, :strategy)

        ##
        # Normalized feed payload consumed by renderers and HTTP responders.
        #
        # @!attribute [r] feed
        #   @return [Html2rss::FeedResult, nil]
        RenderPayload = Data.define(:feed, :site_title, :url)

        ##
        # Shared feed-serving HTTP/cache result wrapper.
        #
        # Wraps a gem {Html2rss::FeedResult} (when present) with web-owned status, TTL,
        # cache key, and error metadata for responders — not a second gem feed type.
        RenderResult = Data.define(:status, :payload, :message, :ttl_seconds, :cache_key, :error_message,
                                   :empty_reason, :strategy_attempts) do
          class << self
            ##
            # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
            alias_method :__new, :new
            private :__new

            # Defaults keep existing keyword call sites stable when attempts are absent.
            #
            # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
            def new(**)
              __new(strategy_attempts: [], **)
            end
          end
        end
      end
    end
  end
end
