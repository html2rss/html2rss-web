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
            nil
          end
        end
      end
    end
  end
end
