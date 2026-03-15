# frozen_string_literal: true

require 'zeitwerk'

module Html2rss
  module Web
    ##
    # Boot helpers for code loading and runtime setup.
    module Boot
      class << self
        # @param reloadable [Boolean]
        # @return [Zeitwerk::Loader]
        def setup!(reloadable: false)
          return loader if setup?

          loader.enable_reloading if reloadable
          loader.setup
          @setup = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          loader
        end

        # @return [Zeitwerk::Loader]
        def loader
          @loader ||= build_loader # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # @return [Boolean]
        def setup?
          # Loader setup happens once during process boot.
          # rubocop:disable ThreadSafety/ClassInstanceVariable
          @setup == true
          # rubocop:enable ThreadSafety/ClassInstanceVariable
        end

        # @return [void]
        def eager_load!
          loader.eager_load
        end

        # @return [void]
        def reload!
          loader.reload
        end

        private

        # @return [Zeitwerk::Loader]
        def build_loader
          Zeitwerk::Loader.new.tap do |new_loader|
            configure_loader(new_loader)
          end
        end

        # @param new_loader [Zeitwerk::Loader]
        # @return [void]
        def configure_loader(new_loader)
          new_loader.push_dir(app_root, namespace: Html2rss)
          collapsed_web_dirs.each { |path| new_loader.collapse(path) }
          new_loader.inflector.inflect('api_v1' => 'ApiV1')
        end

        # @return [Array<String>]
        def collapsed_web_dirs
          %w[config domain errors http rendering request security telemetry].map do |dir|
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
