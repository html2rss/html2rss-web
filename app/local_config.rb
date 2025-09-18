# frozen_string_literal: true

require 'yaml'

module Html2rss
  module Web
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
      # @return [Hash<Symbol, Any>]
      def find(name)
        feeds.fetch(name.to_sym) { raise NotFound, "Did not find local feed config at '#{name}'" }
      end

      ##
      # @return [Hash<Symbol, Any>]
      def feeds
        yaml.fetch(:feeds, {})
      end

      ##
      # @return [Hash<Symbol, Any>]
      def global
        yaml.reject { |key| key == :feeds }
      end

      ##
      # @return [Array<Hash>] configured auth accounts
      def auth_accounts
        global.dig(:auth, :accounts) || []
      end

      ##
      # @return [Array<Symbol>] names of locally available feeds
      def feed_names
        feeds.keys
      end

      ##
      # @return [Hash<Symbol, Any>]
      def yaml
        YAML.safe_load_file(CONFIG_FILE, symbolize_names: true).freeze
      rescue Errno::ENOENT => error
        raise NotFound, "Configuration file not found: #{error.message}"
      end
    end
  end
end
