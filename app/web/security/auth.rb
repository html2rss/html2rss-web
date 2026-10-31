# frozen_string_literal: true

module Html2rss
  ##
  # Web application modules for html2rss
  module Web
    ##
    # Request authentication helpers.
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
          RequestContext.current&.then { RequestContext.set!(it.with(actor: account[:username])) }
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
      end
    end
  end
end
