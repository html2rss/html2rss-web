# frozen_string_literal: true

module Html2rss
  class Selectors
    module PostProcessors
      ##
      # All post processors must inherit from this base class and implement `self.validate_args!` and `#get`.
      class Base
        # Validates the presence of required options in the context
        #
        # @param keys [Array<Symbol>] the keys to check for presence
        # @param context [Selectors::Context] the context containing options
        # @return [void]
        # @raise [MissingOption] if any key is missing
        def self.expect_options(keys, context)
          keys.each do |key|
            unless (options = context[:options]).key?(key)
              raise MissingOption, "The `#{key}` option is missing in: #{options.inspect}", [],
                    cause: nil
            end
          end
        end

        # Asserts that the value is of the expected type(s)
        #
        # @param value [Object] the value to check
        # @param types [Array<Class>, Class] the expected type(s)
        # @param name [String] the name of the option being checked
        # @param context [Selectors::Context] call-site context used for richer validation errors
        # @return [void]
        # @raise [InvalidType] if the value is not of the expected type(s)
        def self.assert_type(value, types = [], name, context:)
          return if Array(types).any? { |type| value.is_a?(type) }

          options = if context.respond_to?(:options)
                      context.options
                    else
                      { file: File.basename(caller(1, 1).first.split(':').first) }
                    end
          message = "The type of `#{name}` must be #{Array(types).join(' or ')}, " \
                    "but is: #{value.class} in: #{options.inspect}"
          raise InvalidType, message, [], cause: nil
        end

        ##
        # This method validates the arguments passed to the post processor. Must be implemented by subclasses.
        #
        # @param _value [Object] extracted selector value
        # @param _context [Selectors::Context] post-processor execution context
        # @return [void]
        def self.validate_args!(_value, _context)
          raise NotImplementedError, 'You must implement the `validate_args!` method in the post processor'
        end

        # Initializes the post processor
        #
        # @param value [Object] the value to be processed
        # @param context [Selectors::Context] runtime selector context and options
        def initialize(value, context)
          klass = self.class
          klass.assert_type(context, Selectors::Context, 'context', context:)
          klass.validate_args!(value, context)

          @value = value
          @context = context
        end

        attr_reader :value, :context

        # Abstract method to be implemented by subclasses
        #
        # @return [Object] transformed value
        # @raise [NotImplementedError] if not implemented in subclass
        def get
          raise NotImplementedError, 'You must implement the `get` method in the post processor'
        end
      end
    end
  end
end
