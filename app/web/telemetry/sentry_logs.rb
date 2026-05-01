# frozen_string_literal: true

require_relative '../security/log_sanitizer'

module Html2rss
  module Web
    ##
    # Mirrors structured application logs into Sentry when log intake is
    # enabled for the current runtime.
    module SentryLogs
      OMIT = Object.new.freeze
      ALLOWED_LEVELS = %i[debug info warn error fatal].freeze
      SENSITIVE_ATTRIBUTE_KEYS = %w[actor email ip remote_ip user_agent username x_forwarded_for].freeze
      BREADCRUMB_KEYS = %i[event_name security_event outcome request_id route_group strategy component details].freeze
      BREADCRUMB_CATEGORY_KEYS = %i[event_name security_event component].freeze
      BREADCRUMB_MESSAGE_KEYS = %i[message event_name security_event component].freeze

      class << self
        # @param payload [Hash{Symbol=>Object}]
        # @return [void]
        def record_breadcrumb(payload)
          return unless breadcrumb_enabled?

          ::Sentry.add_breadcrumb(
            category: breadcrumb_category(payload),
            message: breadcrumb_message(payload),
            level: breadcrumb_level(payload),
            data: breadcrumb_data(payload)
          )
        rescue StandardError
          nil
        end

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

        # @return [Boolean]
        def breadcrumb_enabled?
          RuntimeEnv.sentry_enabled? &&
            defined?(::Sentry) &&
            ::Sentry.respond_to?(:add_breadcrumb)
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
        # @return [String]
        def breadcrumb_category(payload)
          breadcrumb_label(payload, 'html2rss-web', BREADCRUMB_CATEGORY_KEYS)
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [String]
        def breadcrumb_message(payload)
          breadcrumb_label(payload, 'html2rss-web log', BREADCRUMB_MESSAGE_KEYS)
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [String]
        def breadcrumb_level(payload)
          requested_level = payload.fetch(:level, 'info').to_s.downcase
          return 'warning' if requested_level == 'warn'
          return requested_level if ALLOWED_LEVELS.map(&:to_s).include?(requested_level)

          'info'
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def breadcrumb_data(payload)
          LogSanitizer.sanitize_details(payload).slice(*BREADCRUMB_KEYS)
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

        # @param payload [Hash{Symbol=>Object}]
        # @param fallback [String]
        # @param keys [Array<Symbol>]
        # @return [String]
        def breadcrumb_label(payload, fallback, keys)
          keys.lazy.map { |key| payload[key] }.find(&:itself) || fallback
        end
      end
    end
  end
end
