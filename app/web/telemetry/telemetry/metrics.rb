# frozen_string_literal: true

require 'fileutils'

module Html2rss
  module Web
    module Telemetry
      ##
      # Process-shared Prometheus text for product outcomes and build gauges.
      module Metrics
        CONTENT_TYPE = 'text/plain; version=0.0.4'
        OUTCOME_NAME = :html2rss_outcome_total
        UP_NAME = :html2rss_up
        BUILD_NAME = :html2rss_build_info

        class << self
          # Configures {Prometheus::Client::DataStores::DirectFileStore} for this process.
          # Idempotent. Falcon workers each call this after fork via {Boot.start!}.
          #
          # @return [void]
          def start!
            return if started?

            load_client!
            drop_dead_pid_files!
            install_store!
            register_series!
            mark_up!
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @started = true
            nil
          end

          # Increments +html2rss_outcome_total+ for +labels+.
          #
          # @param labels [Hash{Symbol=>String}]
          # @return [void]
          def increment(labels)
            start!
            outcome_counter.increment(labels:)
            nil
          end

          # Prometheus text exposition for the shared store.
          #
          # @return [String]
          def scrape
            start!
            drop_dead_pid_files!
            ::Prometheus::Client::Formats::Text.marshal(::Prometheus::Client.registry)
          end

          private

          # @return [Boolean]
          def started?
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @started == true
          end

          # @return [void]
          def load_client!
            require 'prometheus/client'
            require 'prometheus/client/data_stores/direct_file_store'
            require 'prometheus/client/formats/text'
            nil
          end

          # @return [void]
          def install_store!
            dir = store_dir
            FileUtils.mkdir_p(dir)
            ::Prometheus::Client.config.data_store = ::Prometheus::Client::DataStores::DirectFileStore.new(dir:)
            nil
          end

          # @return [String]
          def store_dir
            configured = ENV.fetch('PROMETHEUS_MULTIPROC_DIR', '').strip
            return configured unless configured.empty?

            File.join(Dir.tmpdir, 'html2rss-prometheus')
          end

          # @return [void]
          def register_series!
            registry = ::Prometheus::Client.registry
            register_outcome(registry)
            register_gauges(registry)
            nil
          end

          # @param registry [Prometheus::Client::Registry]
          # @return [void]
          def register_outcome(registry)
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @outcome = registry.counter(
              OUTCOME_NAME,
              docstring: 'Closed product outcomes.',
              labels: %i[operation result reason]
            )
            nil
          end

          # @param registry [Prometheus::Client::Registry]
          # @return [void]
          def register_gauges(registry)
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @up = registry.gauge(UP_NAME, docstring: '1 for each live process.',
                                          store_settings: { aggregation: :sum })
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @build = registry.gauge(BUILD_NAME, docstring: 'Build revision.', labels: [:version],
                                                store_settings: { aggregation: :max })
            nil
          end

          # @return [Prometheus::Client::Counter]
          def outcome_counter
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @outcome
          end

          # @return [void]
          def mark_up!
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @up.set(1)
            # rubocop:disable-next ThreadSafety/ClassInstanceVariable
            @build.set(1, labels: { version: Boot.revision })
            nil
          end

          # Removes DirectFileStore files whose process is gone so gauge sums ignore them.
          #
          # @return [void]
          def drop_dead_pid_files!
            Dir.glob(File.join(store_dir, '*.bin')).each do |path|
              pid = path[/___(\d+)\.bin\z/, 1].to_i
              next if pid.zero? || pid == Process.pid || process_alive?(pid)

              File.unlink(path)
            end
            nil
          rescue StandardError
            nil
          end

          # @param pid [Integer]
          # @return [Boolean]
          def process_alive?(pid)
            Process.kill(0, pid)
            true
          rescue Errno::ESRCH
            false
          rescue Errno::EPERM
            true
          end
        end
      end
    end
  end
end
