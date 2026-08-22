# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Actionable registry runtime errors for operators and API handlers.
      module Errors
        # Base error for web registry operations.
        class Error < StandardError; end

        # Raised when registry configuration is invalid or incomplete.
        class ConfigError < Error; end

        # Raised when a registry bundle cannot be loaded.
        class LoadError < Error; end

        # Raised when registry synchronization fails.
        class SyncError < Error; end

        # Raised when a registry id is unknown.
        class UnknownRegistry < Error; end
      end
    end
  end
end
