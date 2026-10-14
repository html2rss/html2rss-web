# frozen_string_literal: true

require 'tempfile'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # One process-local HTML page for studio preview replay.
        #
        # Keyed by the canonical URL {PreviewFeed} already allowed. A different
        # URL replaces the slot after a successful fetch. Empty or failed bodies
        # leave the stored page in place. The slot lasts for the process
        # lifetime; process exit removes the temp file.
        module PreviewPageCache
          Slot = Data.define(:url, :path)
          MUTEX = Mutex.new

          class << self
            ##
            # @param url [String] canonical page URL
            # @return [String, nil] temp file path when this URL is cached
            def path_for(url)
              MUTEX.synchronize do
                current = @slot
                current.path if current&.url == url && File.file?(current.path)
              end
            end

            ##
            # @param url [String] canonical page URL
            # @param config [Hash{Symbol=>Object}] token config from {Feeds::GeneratorInput.for_token}
            # @return [Hash{Symbol=>Object}] +config+, overlaid with +:local_file+ on a hit
            def replay(url, config)
              path = path_for(url)
              return config unless path

              overlay(config, path)
            end

            ##
            # @param url [String] canonical page URL
            # @param result [Html2rss::Test::Result]
            # @return [void]
            def store(url, result)
              body = storable_body(result)
              return unless body

              publish(url, write_body(body))
            end

            ##
            # Drops the slot and its temp file.
            #
            # @return [void]
            def clear!
              publish_slot(nil)
            end

            at_exit { Html2rss::Web::Api::V1::PreviewPageCache.clear! }

            private

            # @param config [Hash{Symbol=>Object}]
            # @param path [String]
            # @return [Hash{Symbol=>Object}]
            def overlay(config, path)
              request = config[:request].is_a?(Hash) ? config[:request].dup : {}
              config.merge(strategy: :local_file, request: request.merge(local_file_path: path))
            end

            # A failed extraction and a blank page are not a new cached document.
            #
            # @param result [Html2rss::Test::Result]
            # @return [String, nil]
            def storable_body(result)
              return unless result.success

              body = result.response_body
              return unless body.is_a?(String)
              return if body.strip.empty?

              body
            end

            # @param url [String]
            # @param path [String]
            # @return [void]
            def publish(url, path)
              publish_slot(Slot.new(url:, path:))
            end

            # @param slot [Slot, nil]
            # @return [void]
            def publish_slot(slot)
              previous = nil
              MUTEX.synchronize do
                previous = @slot
                @slot = slot
              end
              unlink(previous.path) if previous && previous.path != slot&.path
            end

            # @param body [String]
            # @return [String]
            def write_body(body)
              file = Tempfile.create(['preview-page-', '.html'])
              file.write(body)
              file.path
            ensure
              file&.close
            end

            # @param path [String, nil]
            # @return [void]
            def unlink(path)
              File.unlink(path) if path
            rescue Errno::ENOENT
              nil
            end
          end

          private_constant :Slot, :MUTEX
        end
      end
    end
  end
end
