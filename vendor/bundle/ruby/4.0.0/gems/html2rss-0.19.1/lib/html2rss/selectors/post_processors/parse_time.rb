# frozen_string_literal: true

require 'time'
require 'tzinfo'

module Html2rss
  class Selectors
    module PostProcessors
      ##
      # Returns the {https://www.w3.org/Protocols/rfc822/ RFC822} representation of a time.
      #
      # Imagine this HTML structure:
      #
      #     <p>Published on <span>2019-07-02</span></p>
      #
      # YAML usage example:
      #
      #    selectors:
      #      description:
      #        selector: span
      #        post_process:
      #          name: 'parse_time'
      #          time_zone: 'Europe/Berlin'
      #
      # Would return:
      #    "Tue, 02 Jul 2019 00:00:00 +0200"
      #
      # It uses `Time.parse`.
      class ParseTime < Base
        # @param value [String] extracted selector value
        # @param context [Selectors::Context] post-processor context
        # @return [void]
        def self.validate_args!(value, context)
          assert_type(value, String, :value, context:)
          time_zone_value = time_zone(context)

          if time_zone_value.nil? || time_zone_value.empty?
            raise ArgumentError, 'time_zone cannot be nil or empty', [], cause: nil
          end

          assert_type(time_zone_value, String, :time_zone, context:)
        end

        # @param context [Selectors::Context] post-processor context
        # @return [String, nil] configured channel time zone
        def self.time_zone(context) = context.dig(:config, :channel, :time_zone)

        ##
        # Converts the provided time string to RFC822 format, taking into account the time_zone.
        #
        # @return [String] RFC822 formatted time
        # @raise [TZInfo::InvalidTimezoneIdentifier] if the configured time zone is invalid
        def get
          with_timezone(time_zone) { Time.parse(value).rfc822 }
        end

        private

        def time_zone
          self.class.time_zone(context)
        end

        def with_timezone(time_zone)
          return yield if time_zone.nil? || time_zone.empty?

          # Validate timezone using TZInfo
          TZInfo::Timezone.get(time_zone)

          prev_tz = ENV.fetch('TZ', Time.now.getlocal.zone)
          ENV['TZ'] = time_zone
          yield
        ensure
          ENV['TZ'] = prev_tz if prev_tz
        end
      end
    end
  end
end
