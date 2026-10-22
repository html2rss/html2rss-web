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

        # Formatter for the html2rss gem logger: JSON line with request_id.
        # Structured gem payloads (JSON with +event_name+) keep columnar fields;
        # free-form strings stay under +message+.
        #
        # @return [Proc]
        def gem_formatter
          lambda do |severity, datetime, _progname, msg|
            format_entry(severity, datetime, nil, gem_message_payload(msg))
          end
        end

        private

        # @param msg [Object]
        # @return [Hash{Symbol=>Object}]
        def gem_message_payload(msg)
          RequestContext.current_h.merge(component: 'html2rss').merge(gem_body(msg))
        end

        # @param msg [Object]
        # @return [Hash{Symbol=>Object}]
        def gem_body(msg)
          structured = gem_structured_payload(msg)
          return sanitize_gem_structured(structured) if structured

          { message: LogSanitizer.sanitize_text(msg.to_s) }
        end

        # @param msg [Object]
        # @return [Hash{Symbol=>Object}, nil]
        def gem_structured_payload(msg)
          candidate = if msg.is_a?(Hash)
                        msg.transform_keys(&:to_sym)
                      elsif json_like?(msg.to_s)
                        parsed = parsed_json(msg.to_s)
                        parsed.is_a?(Hash) ? parsed : nil
                      end
          return unless candidate&.key?(:event_name)

          candidate
        end

        # @param structured [Hash{Symbol=>Object}]
        # @return [Hash{Symbol=>Object}]
        def sanitize_gem_structured(structured)
          LogSanitizer.sanitize_details(structured).tap do |details|
            next unless details[:message].is_a?(String)

            details[:message] = LogSanitizer.sanitize_text(details[:message])
          end
        end

        # @return [Logger]
        def build_logger
          # Falcon workers inherit a block-buffered $stdout when attached to a Docker
          # pipe; sync forces each JSON line to flush immediately for OpenObserve.
          $stdout.sync = true
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
          return message if message.is_a?(Hash)

          message_string = message.to_s
          return parsed_json(message_string) if json_like?(message_string)

          { message: message_string }
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
      end
    end
  end
end
