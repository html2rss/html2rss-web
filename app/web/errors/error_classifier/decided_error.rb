# frozen_string_literal: true

module Html2rss
  module Web
    module ErrorClassifier
      ##
      # Carries an already-computed {Decision} through raise to {ErrorResponder}.
      class DecidedError < StandardError
        # @return [Decision]
        attr_reader :decision
        # @return [Diagnostics]
        attr_reader :diagnostics

        # @param decision [Decision]
        # @param diagnostics [Diagnostics]
        def initialize(decision, diagnostics: Diagnostics::EMPTY)
          @decision = decision
          @diagnostics = diagnostics
          super(decision.message)
        end
      end
    end
  end
end
