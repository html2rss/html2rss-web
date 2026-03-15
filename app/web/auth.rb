# frozen_string_literal: true

require 'openssl'
module Html2rss
  ##
  # Web application modules for html2rss
  module Web
    ##
    # Authentication and feed-token validation helpers.
    #
    # This module keeps auth decisions in one place so route handlers can stay
    # thin and rely on one consistent success/failure contract.
    module Auth
      class << self
        # @param request [Rack::Request]
        # @return [Hash{Symbol=>Object}, nil] account attributes when authenticated.
        def authenticate(request)
          token = extract_token(request)
          return audit_auth(request, nil, 'missing_token') unless token

          account = AccountManager.get_account(token)
          audit_auth(request, account, 'invalid_token')
        end

        # @param username [String]
        # @param url [String]
        # @param strategy [String]
        # @param expires_in [Integer] seconds (default: 10 years)
        # @return [String, nil] signed feed token when generation succeeds.
        def generate_feed_token(username, url, strategy:, expires_in: FeedToken::DEFAULT_EXPIRY)
          token = FeedToken.create_with_validation(
            username: username,
            url: url,
            strategy: strategy,
            expires_in: expires_in,
            secret_key: secret_key
          )
          token&.encode
        end

        # @param token [String]
        # @return [Html2rss::Web::FeedToken, nil]
        def validate_and_decode_feed_token(token)
          decoded = FeedToken.decode(token)
          return unless decoded

          with_validated_token(token, decoded.url) { |validated| validated }
        end

        private

        # @param request [Rack::Request]
        # @param reason [String]
        # @return [nil] always nil to preserve authenticate return contract.
        def log_auth_failure(request, reason)
          SecurityLogger.log_auth_failure(request.ip, request.user_agent, reason)
          nil
        end

        # @param account [Hash{Symbol=>Object}]
        # @param request [Rack::Request]
        # @return [Hash{Symbol=>Object}] unchanged account payload.
        def log_auth_success(account, request)
          assign_request_context_actor(account[:username])
          SecurityLogger.log_auth_success(account[:username], request.ip)
          account
        end

        # @param request [Rack::Request]
        # @return [String, nil]
        def extract_token(request)
          auth_header = request.env['HTTP_AUTHORIZATION']
          return unless auth_header&.start_with?('Bearer ')

          token = auth_header.delete_prefix('Bearer ')
          return nil if token.empty? || token.length > 1024

          token
        end

        # Keeps success/failure logging in one branch so authenticate remains
        # easy to scan.
        #
        # @param request [Rack::Request]
        # @param account [Hash{Symbol=>Object}, nil]
        # @param failure_reason [String]
        # @return [Hash{Symbol=>Object}, nil]
        def audit_auth(request, account, failure_reason)
          if account
            Observability.emit(event_name: 'auth.authenticate', outcome: 'success',
                               details: { username: account[:username] }, level: :info)
            return log_auth_success(account, request)
          end

          Observability.emit(event_name: 'auth.authenticate', outcome: 'failure',
                             details: { reason: failure_reason }, level: :warn)
          log_auth_failure(request, failure_reason)
        end

        # Validates token integrity, records token-usage telemetry, and yields
        # only when token checks pass.
        #
        # @param feed_token [String, nil]
        # @param url [String, nil]
        # @yieldparam token [Html2rss::Web::FeedToken]
        # @return [Object, nil] block result when valid, otherwise nil.
        def with_validated_token(feed_token, url)
          return nil unless feed_token && url

          token = FeedToken.validate_and_decode(feed_token, url, secret_key)
          assign_request_context_strategy(token&.strategy)
          SecurityLogger.log_token_usage(feed_token, url, !token.nil?)
          return nil unless token

          yield token
        end

        # @return [String]
        def secret_key
          ENV.fetch('HTML2RSS_SECRET_KEY')
        end

        # @param username [String, nil]
        # @return [void]
        def assign_request_context_actor(username)
          context = RequestContext.current
          return unless context && username

          RequestContext.set!(context.with(actor: username))
        end

        # @param strategy [String, nil]
        # @return [void]
        def assign_request_context_strategy(strategy)
          context = RequestContext.current
          return unless context && strategy

          RequestContext.set!(context.with(strategy: strategy))
        end
      end
    end
  end
end
