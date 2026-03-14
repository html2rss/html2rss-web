# frozen_string_literal: true

require 'digest'

require_relative '../account_manager'
require_relative '../auth'
require_relative '../auto_source'
require_relative '../cache_ttl'
require_relative '../exceptions'
require_relative '../local_config'
require_relative '../url_validator'
require_relative '../api/v1/contract'
require_relative 'resolved_source'

module Html2rss
  module Web
    module Feeds
      ##
      # Resolves static and token-backed requests into shared generator inputs.
      module Resolver
        class << self
          # @param feed_request [Html2rss::Web::Feeds::Request]
          # @return [Html2rss::Web::Feeds::ResolvedSource]
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

          # @param feed_request [Html2rss::Web::Feeds::Request]
          # @return [Html2rss::Web::Feeds::ResolvedSource]
          def resolve_static(feed_request)
            config = LocalConfig.find(feed_request.feed_name)
            config[:params] = (config[:params] || {}).merge(feed_request.params) if feed_request.params.any?
            config[:strategy] ||= Html2rss::RequestService.default_strategy_name

            ResolvedSource.new(
              source_kind: :static,
              cache_identity: static_cache_identity(feed_request.feed_name, feed_request.params),
              generator_input: config,
              ttl_seconds: CacheTtl.seconds_from_minutes(config.dig(:channel, :ttl))
            )
          end

          # @param feed_request [Html2rss::Web::Feeds::Request]
          # @return [Html2rss::Web::Feeds::ResolvedSource]
          def resolve_token(feed_request)
            feed_token = validated_feed_token(feed_request.token)
            strategy = resolved_strategy(feed_token)
            generator_input = token_generator_input(feed_token.url, strategy)

            ResolvedSource.new(
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

          # @param token [String]
          # @return [String]
          def token_cache_identity(token)
            "token:#{Digest::SHA256.hexdigest(token.to_s)}"
          end

          # @param token [String]
          # @return [Html2rss::Web::FeedToken]
          def validated_feed_token(token)
            feed_token = Auth.validate_and_decode_feed_token(token)
            raise UnauthorizedError, 'Invalid token' unless feed_token

            account = AccountManager.get_account_by_username(feed_token.username)
            raise UnauthorizedError, 'Account not found' unless account

            ensure_token_access!(account, feed_token.url)
            ensure_auto_source_enabled!
            feed_token
          end

          # @param account [Hash{Symbol=>Object}]
          # @param url [String]
          # @return [void]
          def ensure_token_access!(account, url)
            raise ForbiddenError, 'Access Denied' unless UrlValidator.url_allowed?(account, url)
          end

          # @return [void]
          def ensure_auto_source_enabled!
            raise ForbiddenError, Api::V1::Contract::MESSAGES[:auto_source_disabled] unless AutoSource.enabled?
          end

          # @param feed_token [Html2rss::Web::FeedToken]
          # @return [String]
          def resolved_strategy(feed_token)
            strategy = feed_token.strategy.to_s.strip
            strategy = Html2rss::RequestService.default_strategy_name.to_s if strategy.empty?
            supported = Html2rss::RequestService.strategy_names.map(&:to_s)
            raise BadRequestError, 'Unsupported strategy' unless supported.include?(strategy)

            strategy
          end

          # @param url [String]
          # @param strategy [String]
          # @return [Hash{Symbol=>Object}]
          def token_generator_input(url, strategy)
            LocalConfig.global
                       .slice(:stylesheets, :headers)
                       .merge(
                         strategy: strategy.to_sym,
                         channel: { url: url },
                         auto_source: {}
                       )
          end
        end
      end
    end
  end
end
