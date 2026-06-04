# frozen_string_literal: true

module Html2rss
  class Config
    # Processes and applies dynamic parameter formatting in configuration values.
    class DynamicParams
      # Raised when string interpolation references an unavailable parameter.
      class ParamsMissing < Html2rss::Error; end

      class << self
        # Recursively traverses the given value and formats any strings containing
        # placeholders with values from the provided params.
        #
        # @param value [String, Hash, Enumerable, Object] value that may contain parameter placeholders
        # @param params [Hash] The parameters for substitution.
        # @param getter [Proc, nil] Optional proc to retrieve a key's value.
        # @param replace_missing_with [Object, nil] Value to substitute if a key is missing.
        # @return [Object] The processed value.
        def call(value, params = {}, getter: nil, replace_missing_with: nil)
          case value
          when String
            from_string(value, params, getter:, replace_missing_with:)
          when Hash
            from_hash(value, params, getter:, replace_missing_with:)
          when Enumerable
            from_enumerable(value, params, getter:, replace_missing_with:)
          else
            value
          end
        end

        private

        def format_params(params, getter:, replace_missing_with:)
          Hash.new do |hash, key|
            hash[key] = if getter
                          getter.call(key)
                        else
                          params.fetch(key.to_sym) { params[key.to_s] }
                        end
            hash[key] = replace_missing_with if hash[key].nil? && !replace_missing_with.nil?
            hash[key]
          end
        end

        def from_string(string, params, getter:, replace_missing_with:)
          # Return the original string if no format placeholders are found.
          return string unless /%\{[^{}]*\}|%<[^<>]*>/.match?(string)

          mapping = format_params(params, getter:, replace_missing_with:)
          format(string, mapping)
        rescue KeyError => error
          raise ParamsMissing, "Missing parameter for formatting: #{error.message}" if replace_missing_with.nil?

          string
        end

        def from_hash(hash, params, getter:, replace_missing_with:)
          HashUtil.deep_symbolize_keys(hash, context: 'dynamic params hash').to_h do |key, value|
            [key, call(value, params, getter:, replace_missing_with:)]
          end
        end

        def from_enumerable(enumerable, params, getter:, replace_missing_with:)
          enumerable.map { |value| call(value, params, getter:, replace_missing_with:) }
        end
      end
    end
  end
end
