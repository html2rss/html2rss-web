# frozen_string_literal: true

require 'json'
require 'logger'
require 'time'

module Html2rss
  module Web
    ##
    # Shared structured logger for application and middleware runtime events.
    module AppLogger
      class << self
        # @return [Logger]
        def logger
          Thread.current[:app_logger] ||= build_logger
        end

        # @return [void]
        def reset_logger!
          Thread.current[:app_logger] = nil
        end

        private

        # @return [Logger]
        def build_logger
          Logger.new($stdout).tap do |log|
            log.formatter = method(:format_entry)
          end
        end

        # @param severity [String]
        # @param datetime [Time]
        # @param _progname [String, nil]
        # @param message [String]
        # @return [String]
        def format_entry(severity, datetime, _progname, message)
          payload = base_payload(severity, datetime).merge(normalize_message(message))
          emit_to_sentry(payload)
          "#{payload.to_json}\n"
        end

        # @param severity [String]
        # @param datetime [Time]
        # @return [Hash{Symbol=>Object}]
        def base_payload(severity, datetime)
          {
            timestamp: datetime.iso8601,
            level: severity,
            service: 'html2rss-web'
          }
        end

        # @param message [Object]
        # @return [Hash{Symbol=>Object}]
        def normalize_message(message)
          message_string = message.to_s
          return parsed_json(message_string) if json_like?(message_string)

          parse_logfmt(message_string) || { message: message_string }
        end

        # @param message [String]
        # @return [Hash{Symbol=>Object}, nil]
        def parsed_json(message)
          JSON.parse(message, symbolize_names: true)
        rescue JSON::ParserError, TypeError
          nil
        end

        # @param message [String]
        # @return [Boolean]
        def json_like?(message)
          stripped = message.lstrip
          stripped.start_with?('{', '[')
        end

        # @param message [String]
        # @return [Hash{Symbol=>Object}, nil]
        def parse_logfmt(message)
          pairs = message.scan(/([a-zA-Z0-9_.-]+)=("[^"]*"|\S+)/)
          return nil if pairs.empty?

          pairs.to_h do |key, raw_value|
            [key.to_sym, normalize_logfmt_value(raw_value)]
          end
        end

        # @param raw_value [String]
        # @return [String, Integer, Float, TrueClass, FalseClass]
        def normalize_logfmt_value(raw_value)
          value = raw_value.delete_prefix('"').delete_suffix('"')
          return true if value == 'true'
          return false if value == 'false'
          return value.to_i if value.match?(/\A-?\d+\z/)
          return value.to_f if value.match?(/\A-?\d+\.\d+\z/)

          value
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [void]
        def emit_to_sentry(payload)
          return unless sentry_payload?(payload)

          SentryLogs.emit(payload)
        rescue StandardError
          nil
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [Boolean]
        def sentry_payload?(payload)
          payload.key?(:event_name) || payload.key?(:security_event)
        end
      end
    end
  end
end
