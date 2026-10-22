# frozen_string_literal: true

require 'digest'

module Html2rss
  module Web
    ##
    # Audit-channel security logging (auth, rate-limit, token).
    # Operational cache/config events use {Observability} instead.
    module SecurityLogger
      class << self
        # @param ip [String]
        # @param user_agent [String]
        # @param reason [String]
        # @return [void]
        def log_auth_failure(ip, user_agent, reason)
          log_event('auth_failure', { ip:, user_agent:, reason: }, severity: :warn)
        end

        # @param username [String]
        # @param ip [String]
        # @return [void]
        def log_auth_success(username, ip)
          log_event('auth_success', { username:, ip: }, severity: :info)
        end

        # @param ip [String]
        # @param endpoint [String]
        # @param limit [Integer]
        # @return [void]
        def log_rate_limit_exceeded(ip, endpoint, limit)
          log_event('rate_limit_exceeded', { ip:, endpoint:, limit: }, severity: :warn)
        end

        # @param feed_token [String]
        # @param url [String]
        # @param success [Boolean]
        # @return [void]
        def log_token_usage(feed_token, url, success)
          log_event(
            'token_usage',
            { success:, url:, token_hash: Digest::SHA256.hexdigest(feed_token)[0..7] },
            severity: success ? :info : :warn
          )
        end

        # @param ip [String]
        # @param activity [String]
        # @param details [Hash]
        # @return [void]
        def log_suspicious_activity(ip, activity, details = {})
          log_event('suspicious_activity', { ip:, activity:, **details }, severity: :warn)
        end

        private

        # @param event_type [String]
        # @param data [Hash]
        # @param severity [Symbol]
        # @return [void]
        def log_event(event_type, data, severity: :warn)
          LogEvent.emit(
            level: severity,
            payload: { event_name: event_type, details: data }
          )
        end
      end
    end
  end
end
