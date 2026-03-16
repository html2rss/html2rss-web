# frozen_string_literal: true

module Html2rss
  module Web
    module Boot
      ##
      # Applies boot-time runtime configuration outside the Roda class body.
      module Setup
        class << self
          # Validates environment configuration and wires the request service.
          #
          # @return [void]
          def call!
            validate_environment!
            configure_request_service!
          end

          private

          # @return [void]
          def validate_environment!
            EnvironmentValidator.validate_environment!
            EnvironmentValidator.validate_production_security!
            Flags.validate!
          end

          # @return [void]
          def configure_request_service!
            Html2rss::RequestService.register_strategy(:ssrf_filter, SsrfFilterStrategy)
            Html2rss::RequestService.default_strategy_name = preferred_default_strategy
            Html2rss::RequestService.unregister_strategy(:faraday)
          end

          # @return [Symbol]
          def preferred_default_strategy
            supported = Html2rss::RequestService.strategy_names.map(&:to_sym)
            return :browserless if supported.include?(:browserless)

            :ssrf_filter
          end
        end
      end
    end
  end
end
