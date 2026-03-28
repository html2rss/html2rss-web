# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Mirrors structured application logs into Sentry when log intake is
    # enabled for the current runtime.
    module SentryLogs
      OMIT = Object.new.freeze
      ALLOWED_LEVELS = %i[debug info warn error fatal].freeze
      SENSITIVE_ATTRIBUTE_KEYS = %w[actor email ip remote_ip user_agent username x_forwarded_for].freeze

      class << self
        # @param payload [Hash{Symbol=>Object}]
        # @return [void]
        def emit(payload)
          return unless enabled?

          logger.public_send(level(payload), message(payload), **attributes(payload))
        rescue StandardError
          nil
        end

        private

        # @return [Boolean]
        def enabled?
          RuntimeEnv.sentry_enabled? &&
            RuntimeEnv.sentry_logs_enabled? &&
            defined?(::Sentry) &&
            !logger.nil?
        end

        # @return [Object, nil]
        def logger
          return unless defined?(::Sentry) && ::Sentry.respond_to?(:logger)

          ::Sentry.logger
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [Symbol]
        def level(payload)
          requested_level = payload.fetch(:level, 'INFO').to_s.downcase.to_sym
          return requested_level if ALLOWED_LEVELS.include?(requested_level)

          :info
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [String]
        def message(payload)
          payload[:message] || payload[:event_name] || payload[:security_event] ||
            payload[:component] || 'html2rss-web log'
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def attributes(payload)
          sanitize_hash(payload).tap do |attributes|
            attributes.delete(:message)
            attributes.delete(:level)
          end
        end

        # @param payload [Hash]
        # @return [Hash]
        def sanitize_hash(payload)
          payload.each_with_object({}) do |(key, value), sanitized|
            sanitized_value = sanitize_value(key, value)
            next if sanitized_value.equal?(OMIT)

            sanitized[key] = sanitized_value
          end
        end

        # @param key [Object]
        # @param value [Object]
        # @return [Object]
        def sanitize_value(key, value)
          return OMIT if sensitive_key?(key)
          return sanitize_hash(value) if value.is_a?(Hash)
          return sanitize_array(key, value) if value.is_a?(Array)

          value
        end

        # @param key [Object]
        # @param values [Array]
        # @return [Array]
        def sanitize_array(key, values)
          values.map { |entry| sanitize_value(key, entry) }
                .reject { |entry| entry.equal?(OMIT) }
        end

        # @param key [Object]
        # @return [Boolean]
        def sensitive_key?(key)
          SENSITIVE_ATTRIBUTE_KEYS.include?(key.to_s)
        end
      end
    end
  end
end
