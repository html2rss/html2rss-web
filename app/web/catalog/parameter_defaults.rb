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

          parameters_block.each_with_object({}) do |(name, config), defaults|
            next unless config.is_a?(Hash) && config.key?(:default)

            defaults[name.to_s] = config[:default]
          end
        end
      end
    end
  end
end
