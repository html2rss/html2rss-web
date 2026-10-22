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
        # @param strategy [String, nil]
        # @param expires_in [Integer] seconds (default: 10 years)
        # @return [String, nil] signed feed token when generation succeeds.
        def generate_feed_token(username, url, strategy: nil, expires_in: FeedToken::DEFAULT_EXPIRY)
          token = FeedToken::Signer.create(
            username: username,
            url: url,
            strategy: strategy,
            expires_in: expires_in,
            secret_key: RuntimeEnv.secret_key
          )
          token && FeedToken::Codec.encode(token)
        end

        # @param token [String]
        # @return [Html2rss::Web::FeedToken, nil]
        def validate_and_decode_feed_token(token)
          decoded = FeedToken::Codec.decode(token)
          return unless decoded

          validated = FeedToken::Signer.validate_decoded(decoded, decoded.url, RuntimeEnv.secret_key)
          assign_request_context_strategy(validated&.strategy)
          SecurityLogger.log_token_usage(token, decoded.url, !validated.nil?)
          validated
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

        private

        # Keeps success/failure logging in one branch so authenticate remains
        # easy to scan.
        #
        # @param request [Rack::Request]
        # @param account [Hash{Symbol=>Object}, nil]
        # @param failure_reason [String]
        # @return [Hash{Symbol=>Object}, nil]
        def audit_auth(request, account, failure_reason)
          return complete_auth_success(account, request) if account

          emit_auth_outcome('failure', { reason: failure_reason }, :warn)
          SecurityLogger.log_auth_failure(request.ip, request.user_agent, failure_reason)
          nil
        end

        # @param account [Hash{Symbol=>Object}]
        # @param request [Rack::Request]
        # @return [Hash{Symbol=>Object}]
        def complete_auth_success(account, request)
          emit_auth_outcome('success', { username: account[:username] }, :info)
          assign_request_context_actor(account[:username])
          SecurityLogger.log_auth_success(account[:username], request.ip)
          account
        end

        # @param outcome [String]
        # @param details [Hash{Symbol=>Object}]
        # @param level [Symbol]
        # @return [void]
        def emit_auth_outcome(outcome, details, level)
          Observability.emit(event_name: 'auth.authenticate', outcome:, details:, level:)
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
