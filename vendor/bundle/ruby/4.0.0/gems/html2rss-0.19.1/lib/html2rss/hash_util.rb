# frozen_string_literal: true

module Html2rss
  # Shared helpers for hash normalization and structural operations.
  module HashUtil
    module_function

    # Deeply duplicates nested arrays and hashes.
    #
    # @param object [Object] nested value from configuration or runtime state
    # @return [Object] deep duplicated object
    def deep_dup(object)
      case object
      in Hash
        object.transform_values { deep_dup(_1) }
      in Array
        object.map { deep_dup(_1) }
      else
        object.dup rescue StandardError # rubocop:disable Style/RescueModifier
      end
    end

    # Deeply merges nested hashes while replacing non-hash values from override.
    #
    # @param base [Hash] base hash
    # @param override [Hash] override hash
    # @return [Hash] merged hash
    def deep_merge(base, override)
      base.merge(override) do |_key, old_val, new_val|
        case [old_val, new_val]
        in [Hash, Hash]
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end

    # Converts string-keyed hashes to symbol-keyed hashes recursively.
    #
    # @param object [Object] value to normalize
    # @param context [String] error context
    # @return [Object] normalized value
    def deep_symbolize_keys(object, context: 'hash')
      case object
      in Hash
        object.each_with_object({}) do |(k, v), memo|
          memo[symbol_key(k, context:)] = deep_symbolize_keys(v, context:)
        end
      in Array
        object.map { deep_symbolize_keys(_1, context:) }
      else
        object
      end
    end

    # Validates that hash keys are symbols.
    #
    # @param value [Object] candidate hash container whose keys must be symbols
    # @param context [String] error context
    # @param deep [Boolean] whether nested hashes should also be validated
    # @return [void]
    def assert_symbol_keys!(value, context: 'hash', deep: true)
      return unless value in Hash

      unless value.each_key.all?(Symbol)
        invalid_key = value.keys.find { _1.class != Symbol }
        raise ArgumentError, "#{context} must use symbol keys (found #{invalid_key.inspect})"
      end

      value.each_value { assert_symbol_keys!(_1, context:, deep:) } if deep
    end

    # Validates that hash keys are strings.
    #
    # @param value [Object] candidate hash container whose keys must be strings
    # @param context [String] error context
    # @param deep [Boolean] whether nested hashes should also be validated
    # @return [void]
    def assert_string_keys!(value, context: 'hash', deep: true)
      return unless value in Hash

      unless value.each_key.all?(String)
        invalid_key = value.keys.find { _1.class != String }
        raise ArgumentError, "#{context} must use string keys (found #{invalid_key.inspect})"
      end

      value.each_value { assert_string_keys!(_1, context:, deep:) } if deep
    end

    def symbol_key(key, context:)
      case key
      in Symbol then key
      in String then key.to_sym
      else
        raise ArgumentError, "#{context} must use string or symbol keys (found #{key.inspect})"
      end
    end
    private_class_method :symbol_key
  end
end
