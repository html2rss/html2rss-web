# frozen_string_literal: true

require 'json'
require 'logger'
require 'time'
module Html2rss
  module Web
    module AppLogger
      class << self
        # rubocop:disable ThreadSafety/ClassInstanceVariable
        # @return [Logger]
        def logger
          @logger ||= build_logger
        end

        # @return [void]
        def reset_logger!
          @logger = nil
        end
        # rubocop:enable ThreadSafety/ClassInstanceVariable

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
          return "#{human_line(payload)}\n" if development?

          "#{payload.to_json}\n"
        end

        # @param severity [String]
        # @param datetime [Time]
        # @return [Hash{Symbol=>Object}]
        def base_payload(severity, datetime)
          {
            timestamp: utc_timestamp(datetime),
            level: severity,
            service: 'html2rss-web'
          }
        end

        # @param datetime [Time]
        # @return [String]
        def utc_timestamp(datetime)
          datetime.utc.iso8601(3)
        end

        # @return [Boolean]
        def development?
          RuntimeEnv.rack_env == 'development'
        end

        # @param payload [Hash{Symbol=>Object}]
        # @return [String]
        def human_line(payload)
          fields = payload.map { |key, value| "#{key}=#{human_value(value)}" }
          fields.join(' ').gsub(/[\r\n]+/, ' ')
        end

        # @param value [Object]
        # @return [String]
        def human_value(value)
          return 'null' if value.nil?

          text = value.to_s.gsub(/[\r\n]+/, ' ')
          text.match?(/[\s=]/) ? text.inspect : text
        end

        # @param message [Object]
        # @return [Hash{Symbol=>Object}]
        def normalize_message(message)
          return message if message.is_a?(Hash)

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
      end
    end
  end
end
