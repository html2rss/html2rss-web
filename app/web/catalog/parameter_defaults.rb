# frozen_string_literal: true

module Html2rss
  module Web
    module Catalog
      ##
      # Sole owner of directory/catalog parameter-defaults expansion in the web
      # app. Same algorithm as +Html2rss::Configs::Catalog+ +default_parameters+.
      module ParameterDefaults
        module_function

        ##
        # Extracts string-keyed defaults from a feed +parameters+ block.
        #
        # @param parameters_block [Hash, nil]
        # @return [Hash{String => Object}]
        def extract(parameters_block)
          return {} unless parameters_block.is_a?(Hash)

          parameters_block.filter_map { |name, config| [name.to_s, config[:default]] if config in { default: _ } }.to_h
        end
      end
    end
  end
end
