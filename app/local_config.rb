# frozen_string_literal: true

##
# Provides helper methods to deal with the local config file at `CONFIG_FILE`.
module LocalConfig
  class NotFound < StandardError; end

  CONFIG_FILE = 'config/feeds.yml'

  module_function

  ##
  # @return [Hash<Symbol, Hash>]
  def find(name)
    feeds&.fetch(name, false) || raise(NotFound, "Did not find local feed config at '#{name}'")
  end

  ##
  # @return [Hash<Symbol, Hash>]
  def feeds
    yaml.fetch(:feeds, {})
  end

  ##
  # @return [Hash<Symbol, Hash>]
  def global
    yaml.reject { |key| key == :feeds }
  end

  ##
  # @return [Hash<Symbol, Hash>]
  def yaml
    # TODO: cache in production
    YAML.safe_load(File.open(CONFIG_FILE), symbolize_names: true).freeze
  end
end
