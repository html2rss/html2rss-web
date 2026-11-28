# frozen_string_literal: true

require 'digest'

module Html2rss
  module Web
    module Feeds
      ##
      # Resolves static and token-backed requests into shared generator inputs.
      module SourceResolver
        class << self
          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def call(feed_request)
            case feed_request.target_kind
            when :static
              resolve_static(feed_request)
            when :token
              resolve_token(feed_request)
            else
              raise BadRequestError, "Unsupported feed target: #{feed_request.target_kind}"
            end
          end

          private

          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def resolve_static(feed_request)
            config = LocalConfig.find(feed_request.feed_name)
            build_static_source(feed_request, config)
          rescue LocalConfig::NotFound
            raise NotFoundError
          end

          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @param config [Hash]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def build_static_source(feed_request, config)
            generator_input = static_generator_input(config, feed_request.params)
            resolved_source(
              source_kind: :static,
              cache_identity: static_cache_identity(feed_request.feed_name, feed_request.params),
              generator_input:,
              ttl_seconds: Cache.seconds_from_minutes(generator_input.dig(:channel, :ttl)),
              feed_name: feed_request.feed_name,
              directory_defaults: Catalog::ParameterDefaults.extract(config[:parameters]),
              request_params: feed_request.params.to_h
            )
          end

          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def resolve_token(feed_request)
            ensure_auto_source_enabled!
            feed_token = authorize_feed_token!(feed_request.token)
            build_token_source(feed_request, feed_token)
          end

          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @param feed_token [Html2rss::Web::FeedToken]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def build_token_source(feed_request, feed_token)
            generator_input = token_generator_input(feed_token)
            resolved_source(
              source_kind: :token,
              cache_identity: token_cache_identity(feed_request.token),
              generator_input:,
              ttl_seconds: Cache.seconds_from_minutes(generator_input.dig(:channel, :ttl), default: 300),
              feed_name: nil,
              directory_defaults: {},
              request_params: {}
            )
          end

          # @param kwargs [Hash{Symbol=>Object}]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def resolved_source(**kwargs)
            generator_input = kwargs.fetch(:generator_input)
            Contracts::ResolvedSource.new(
              url: generator_input.dig(:channel, :url),
              strategy: generator_input[:strategy],
              **kwargs
            )
          end

          # @param feed_name [String]
          # @param params [Hash{Object=>Object}]
          # @return [String]
          def static_cache_identity(feed_name, params)
            bag = params.to_h
            digest = bag.empty? ? 'empty' : Digest::SHA256.hexdigest(Marshal.dump(bag.sort_by(&:to_s)))
            "static:#{feed_name}:#{digest}"
          end

          # @param config [Hash{Symbol=>Object}]
          # @param params [Hash{Object=>Object}]
          # @return [Hash{Symbol=>Object}]
          def static_generator_input(config, params)
            config.merge(params: (config[:params] || {}).merge(params))
          end

          # @param token [String]
          # @return [String]
          def token_cache_identity(token)
            "token:#{Digest::SHA256.hexdigest(token.to_s)}"
          end

          # @return [void]
          def ensure_auto_source_enabled!
            return if Flags.auto_source_enabled?

            raise AutoSourceDisabledError
          end

          # @param token [String]
          # @return [Html2rss::Web::FeedToken]
          def authorize_feed_token!(token)
            feed_token = FeedToken.validate(token)
            raise UnauthorizedError, 'Invalid token' unless feed_token

            account = AccountManager.get_account_by_username(feed_token.username)
            raise UnauthorizedError, 'Account not found' unless account
            return feed_token if UrlValidator.url_allowed?(account, feed_token.url)

            raise ForbiddenError, 'Access Denied'
          end

          # Re-validates the signed selectors; only reached after the signature verified.
          #
          # @param feed_token [Html2rss::Web::FeedToken]
          # @return [Hash{Symbol=>Object}]
          def token_generator_input(feed_token)
            GeneratorInput.for_token(url: feed_token.url, strategy: feed_token.strategy,
                                     selectors: SelectorsDocument.parse(feed_token.selectors))
          end
        end
      end
    end
  end
end
