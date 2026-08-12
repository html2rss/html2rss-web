# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      module FormatNegotiation
        ##
        # One Accept media range with quality and source order for negotiation scoring.
        MediaRange = Data.define(:type, :subtype, :quality, :position) do
          # @return [Integer]
          def specificity
            return 0 if type == '*' && subtype == '*'
            return 1 if subtype == '*'

            2
          end

          # @param candidate [String]
          # @return [Boolean]
          def matches?(candidate)
            candidate_type, candidate_subtype = candidate.downcase.split('/', 2)
            return true if type == '*' && subtype == '*'
            return candidate_type == type if subtype == '*'

            candidate_type == type && candidate_subtype == subtype
          end
        end
      end
    end
  end
end
