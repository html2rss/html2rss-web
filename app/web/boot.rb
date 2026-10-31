# frozen_string_literal: true

require 'zeitwerk'

module Html2rss
  module Web
    ##
    # Boot helpers for code loading and runtime setup.
    module Boot
      class << self
        # Builds the Zeitwerk loader and sets it up (Zeitwerk ignores repeated setup). Runs once at boot.
        #
        # @param reloadable [Boolean]
        # @return [Zeitwerk::Loader]
        def setup!(reloadable: false)
          require_relative '../../config/version'
          loader.enable_reloading if reloadable
          loader.setup
          loader
        end

        # @return [Zeitwerk::Loader]
        def loader = @loader ||= build_loader # rubocop:disable ThreadSafety/ClassInstanceVariable -- set once at boot

        # @return [void]
        def eager_load! = loader.eager_load

        # @return [void]
        def reload! = loader.reload

        private

        # @return [Zeitwerk::Loader]
        def build_loader
          Zeitwerk::Loader.new.tap { configure_loader(it) }
        end

        # @param new_loader [Zeitwerk::Loader]
        # @return [void]
        def configure_loader(new_loader)
          new_loader.push_dir(app_root, namespace: Html2rss)
          collapsed_web_dirs.each { |path| new_loader.collapse(path) }
          new_loader.inflector.inflect('api_v1' => 'ApiV1')
        end

        ##
        # Flat utility dirs collapse into +Html2rss::Web+ (e.g. +Auth+,
        # +RateLimiter+) rather than nested namespaces. Nested dirs under
        # +app/web+ (+api+, +boot+, +catalog+, +feeds+, +routes+) keep their
        # own modules.
        #
        # @return [Array<String>]
        def collapsed_web_dirs
          %w[config errors request security telemetry].map do |dir|
            File.join(app_root, 'web', dir)
          end
        end

        ##
        # Returns the application directory that maps to the Html2rss root
        # namespace.
        #
        # @return [String]
        def app_root
          File.expand_path('..', __dir__)
        end
      end
    end
  end
end
