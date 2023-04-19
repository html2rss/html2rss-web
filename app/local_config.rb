# frozen_string_literal: true

require 'yaml'
module App
  ##
  # Provides helper methods to deal with the local config file at `CONFIG_FILE`.
  module LocalConfig
    ##
    # raised when the local config wasn't found
    class NotFound < RuntimeError; end

    CONFIG_FILE = 'config/feeds.yml'

    module_function

    ##
    # @param name [String, Symbol, #to_sym]
    # @return [Hash<Symbol, Hash>]
    def find(name)
      feeds&.fetch(name.to_sym, false) || raise(NotFound, "Did not find local feed config at '#{name}'")
    end

    ##
    # @return [Hash<Symbol, Hash>]
    def feeds
      yaml[:feeds] || {}
    end

    ##
    # @return [Hash<Symbol, Hash>]
    def global
      yaml.reject { |key| key == :feeds }
    end

    ##
    # @return [Array<Symbol>] names of locally available feeds
    def feed_names
      feeds.keys
    end

    ##
    # @return [Hash<Symbol, Hash>]
    def yaml
      @yaml = YAML.safe_load(File.open(CONFIG_FILE), symbolize_names: true).freeze
    end
  end
end
