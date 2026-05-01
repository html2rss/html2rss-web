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
              raise Html2rss::Web::BadRequestError, "Unsupported feed target: #{feed_request.target_kind}"
            end
          end

          private

          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def resolve_static(feed_request)
            config = LocalConfig.find(feed_request.feed_name)
            generator_input = static_generator_input(config, feed_request.params)

            Contracts::ResolvedSource.new(
              source_kind: :static,
              cache_identity: static_cache_identity(feed_request.feed_name, feed_request.params),
              generator_input: generator_input,
              ttl_seconds: CacheTtl.seconds_from_minutes(generator_input.dig(:channel, :ttl))
            )
          rescue Html2rss::Web::LocalConfig::NotFound
            raise Html2rss::Web::NotFoundError
          end

          # @param feed_request [Html2rss::Web::Feeds::Contracts::Request]
          # @return [Html2rss::Web::Feeds::Contracts::ResolvedSource]
          def resolve_token(feed_request)
            ensure_auto_source_enabled!
            feed_token = authorize_feed_token!(feed_request.token)
            strategy = resolved_strategy(feed_token)
            generator_input = token_generator_input(feed_token.url, strategy)

            Contracts::ResolvedSource.new(
              source_kind: :token,
              cache_identity: token_cache_identity(feed_request.token),
              generator_input: generator_input,
              ttl_seconds: CacheTtl.seconds_from_minutes(generator_input.dig(:channel, :ttl), default: 300)
            )
          end

          # @param feed_name [String]
          # @param params [Hash{Object=>Object}]
          # @return [String]
          def static_cache_identity(feed_name, params)
            normalized_params = params.to_h.sort_by { |key, _| key.to_s }
            digest = Digest::SHA256.hexdigest(Marshal.dump(normalized_params))
            "static:#{feed_name}:#{digest}"
          end

          # @param config [Hash{Symbol=>Object}]
          # @param params [Hash{Object=>Object}]
          # @return [Hash{Symbol=>Object}]
          def static_generator_input(config, params)
            generator_input = config.dup
            generator_input[:params] = merged_static_params(config, params)
            generator_input
          end

          # @param config [Hash{Symbol=>Object}]
          # @param params [Hash{Object=>Object}]
          # @return [Hash{Object=>Object}]
          def merged_static_params(config, params)
            return (config[:params] || {}).dup if params.empty?

            (config[:params] || {}).merge(params)
          end

          # @param token [String]
          # @return [String]
          def token_cache_identity(token)
            "token:#{Digest::SHA256.hexdigest(token.to_s)}"
          end

          # @return [void]
          def ensure_auto_source_enabled!
            return if AutoSource.enabled?

            raise Html2rss::Web::AutoSourceDisabledError
          end

          # @param token [String]
          # @return [Html2rss::Web::FeedToken]
          def authorize_feed_token!(token)
            feed_token = Auth.validate_and_decode_feed_token(token)
            raise Html2rss::Web::UnauthorizedError, 'Invalid token' unless feed_token

            account = AccountManager.get_account_by_username(feed_token.username)
            raise Html2rss::Web::UnauthorizedError, 'Account not found' unless account
            return feed_token if UrlValidator.url_allowed?(account, feed_token.url)

            raise Html2rss::Web::ForbiddenError, 'Access Denied'
          end

          # @param feed_token [Html2rss::Web::FeedToken]
          # @return [String]
          def resolved_strategy(feed_token)
            strategy = feed_token.strategy.to_s.strip
            return default_strategy_name if strategy.empty?
            return strategy if strategy == default_strategy_name

            supported = Html2rss::RequestService.strategy_names.map(&:to_s)
            raise Html2rss::Web::BadRequestError, 'Unsupported strategy' unless supported.include?(strategy)

            strategy
          end

          # @param url [String]
          # @param strategy [String]
          # @return [Hash{Symbol=>Object}]
          def token_generator_input(url, strategy)
            global_config = LocalConfig.global
            base_input = global_config.slice(:stylesheets, :headers)
            base_input.merge(channel: { url: url }, auto_source: {}, strategy: strategy.to_sym)
          end

          # @return [String]
          def default_strategy_name
            if Html2rss::Config.respond_to?(:default_strategy_name)
              configured = Html2rss::Config.default_strategy_name.to_s
            end
            return configured unless configured.to_s.strip.empty?

            'auto'
          end
        end
      end
    end
  end
end
