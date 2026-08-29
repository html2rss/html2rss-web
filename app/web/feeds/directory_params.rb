# frozen_string_literal: true

module Html2rss
  module Web
    module Feeds
      ##
      # Pure gate: request params match catalog/directory parameter defaults.
      #
      # Used so {LastResults} only records directory-path scrapes (defaults bag),
      # not custom-parameterized hits.
      module DirectoryParams
        class << self
          ##
          # Returns true when +params+ has no keys beyond +defaults+ and every
          # provided value equals the corresponding default (missing keys OK).
          #
          # @param defaults [Hash]
          # @param params [Hash]
          # @return [Boolean]
          def match?(defaults, params)
            default_bag = normalize_bag(defaults)
            param_bag = normalize_bag(params)
            return false unless (param_bag.keys - default_bag.keys).empty?

            default_bag.merge(param_bag) == default_bag
          end

          private

          # @param bag [Hash]
          # @return [Hash{String => String}]
          def normalize_bag(bag)
            bag.to_h.each_with_object({}) do |(key, value), out|
              out[key.to_s] = value.nil? ? '' : value.to_s
            end
          end
        end
      end
    end
  end
end
