# frozen_string_literal: true

module Html2rss
  module Web
    module Boot
      ##
      # Development-only rack wrapper that reloads Zeitwerk-managed code when
      # application files change.
      class DevelopmentReloader
        WATCH_GLOBS = [
          'app/**/*.rb',
          'app.rb',
          'config/**/*.rb',
          'config/**/*.yml',
          'config.ru'
        ].freeze

        # @param loader [Zeitwerk::Loader]
        # @param app_provider [#call]
        def initialize(loader:, app_provider:)
          @loader = loader
          @app_provider = app_provider
          @latest_mtime = current_mtime
          @reload_mutex = Mutex.new
        end

        # @param env [Hash]
        # @return [Array<(Integer, Hash, #each)>]
        def call(env)
          @reload_mutex.synchronize do
            reload_if_needed
            @app_provider.call.call(env)
          end
        end

        private

        # @return [void]
        def reload_if_needed
          mtime = current_mtime
          return unless mtime && (!@latest_mtime || mtime > @latest_mtime)

          @loader.reload
          reset_runtime_caches!
          @latest_mtime = mtime
        end

        # @return [Time, nil]
        def current_mtime
          watched_files.filter_map do |path|
            next unless File.file?(path)

            File.mtime(path)
          end.max
        end

        # @return [Array<String>]
        def watched_files
          WATCH_GLOBS.flat_map { |pattern| Dir[File.expand_path("../../#{pattern}", __dir__)] }
        end

        # @return [void]
        def reset_runtime_caches!
          Html2rss::Web::LocalConfig.reload!(reason: 'code_reload') if defined?(Html2rss::Web::LocalConfig)
          Html2rss::Web::AccountManager.reload!(reason: 'code_reload') if defined?(Html2rss::Web::AccountManager)
        end
      end
    end
  end
end
