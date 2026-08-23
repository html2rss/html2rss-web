# frozen_string_literal: true

module Html2rss
  module Web
    module Config
      ##
      # Shared helpers for cloning nested Hash/Array config structures.
      module StructuredData
        module_function

        ##
        # @param value [Object]
        # @return [Object]
        def deep_dup(value) # rubocop:disable Metrics/MethodLength
          case value
          when Hash
            value.each_with_object({}) do |(key, val), memo|
              memo[key.is_a?(String) ? key.dup : key] = deep_dup(val)
            end
          when Array
            value.map { deep_dup(it) }
          when String
            value.dup
          else
            value
          end
        end
      end
    end
  end
end
