# frozen_string_literal: true

require 'digest'
module Html2rss
  module Web
    ##
    # Security event logging for html2rss-web
    # Provides structured logging for security events to stdout
    module SecurityLogger
      class << self
        # Reset shared logger state for tests.
        # @return [void]
        def reset_logger!
          AppLogger.reset_logger!
        end

        ##
        # Log authentication failure
        # @param ip [String] client IP address
        # @param user_agent [String] client user agent
        # @param reason [String] failure reason
        # @return [void]
        def log_auth_failure(ip, user_agent, reason)
          log_event('auth_failure', {
                      ip: ip,
                      user_agent: user_agent,
                      reason: reason
                    }, severity: :warn)
        end

        ##
        # Log authentication success
        # @param username [String] authenticated username
        # @param ip [String] client IP address
        # @return [void]
        def log_auth_success(username, ip)
          log_event('auth_success', {
                      username: username,
                      ip: ip
                    }, severity: :info)
        end

        ##
        # Log rate limit exceeded
        # @param ip [String] client IP address
        # @param endpoint [String] endpoint that was rate limited
        # @param limit [Integer] rate limit that was exceeded
        # @return [void]
        def log_rate_limit_exceeded(ip, endpoint, limit)
          log_event('rate_limit_exceeded', {
                      ip: ip,
                      endpoint: endpoint,
                      limit: limit
                    }, severity: :warn)
        end

        ##
        # Log token usage
        # @param feed_token [String] feed token (hashed for privacy)
        # @param url [String] URL being accessed
        # @param success [Boolean] whether the token was valid
        # @return [void]
        def log_token_usage(feed_token, url, success)
          severity = success ? :info : :warn

          log_event('token_usage', {
                      success: success,
                      url: url,
                      token_hash: Digest::SHA256.hexdigest(feed_token)[0..7]
                    }, severity: severity)
        end

        ##
        # Log suspicious activity
        # @param ip [String] client IP address
        # @param activity [String] description of suspicious activity
        # @param details [Hash] additional details
        # @return [void]
        def log_suspicious_activity(ip, activity, details = {})
          log_event('suspicious_activity', {
                      ip: ip,
                      activity: activity,
                      **details
                    }, severity: :warn)
        end

        ##
        # Log blocked request
        # @param ip [String] client IP address
        # @param reason [String] reason for blocking
        # @param endpoint [String] endpoint that was blocked
        # @return [void]
        def log_blocked_request(ip, reason, endpoint)
          log_event('blocked_request', {
                      ip: ip,
                      reason: reason,
                      endpoint: endpoint
                    }, severity: :warn)
        end

        ##
        # Log configuration validation failure
        # @param component [String] component that failed validation
        # @param details [String] validation failure details
        # @param severity [Symbol]
        # @return [void]
        def log_config_validation_failure(component, details, severity: :error)
          log_event('config_validation_failure', {
                      component: component,
                      details: details
                    }, severity: severity)
        end

        # Log lifecycle events for in-memory config/cache snapshots
        # @param component [String] component name
        # @param event [String] lifecycle event name
        # @param details [Hash] optional extra context
        # @return [void]
        def log_cache_lifecycle(component, event, details = {})
          log_event('cache_lifecycle', {
                      component: component,
                      event: event,
                      **details
                    }, severity: :info)
        end

        private

        ##
        # Log a security event
        # @param event_type [String] type of security event
        # @param data [Hash] event data
        def log_event(event_type, data, severity: :warn)
          LogEvent.emit(
            level: severity,
            payload: {
              security_event: event_type,
              details: data
            }
          )
        rescue StandardError => error
          handle_logging_error(error, event_type, data)
        end

        ##
        # Handle logging errors with fallback mechanisms
        # @param error [StandardError] the error that occurred
        # @param event_type [String] type of security event
        # @param data [Hash] event data
        def handle_logging_error(error, event_type, data)
          sanitized_data = LogSanitizer.sanitize_details(data)
          Kernel.warn("Structured logging fallback: #{error.class}: #{error.message}")
          Kernel.warn("component=security_logger security_event=#{event_type} details=#{sanitized_data}")
        end
      end
    end
  end
end
