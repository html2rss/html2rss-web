# frozen_string_literal: true

require 'yaml'
require 'openssl'

module Html2rss
  module Web
    module Registry
      ##
      # Registry definition parsed from {Config::REGISTRIES_FILE}.
      Entry = Data.define(
        :id,
        :mode,
        :path,
        :sync_channel,
        :sync_url,
        :catalog,
        :public_key_id,
        :public_key
      ) do
        ##
        # @return [Hash{String => OpenSSL::PKey::PKey}]
        def public_keys
          return {} if public_key.nil?

          { public_key_id => public_key }
        end
      end

      ##
      # Parses registry configuration and applies zero-config defaults.
      module Config # rubocop:disable Metrics/ModuleLength
        REGISTRIES_FILE = 'config/registries.yml'
        DEFAULT_PRECEDENCE = %w[official].freeze
        DEFAULT_OFFICIAL_SYNC_CHANNEL = 'html2rss-official'
        OFFICIAL_RELEASE_URL = 'https://github.com/html2rss/html2rss-configs/releases/latest/download/registry-bundle.tar.gz'

        @mutex = Mutex.new
        @current = nil

        class << self # rubocop:disable Metrics/ClassLength
          ##
          # @return [Array<String>] registry ids in merge precedence order
          def precedence
            current.precedence
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Entry]
          def entry(registry_id)
            current.entries.fetch(registry_id.to_s) do
              raise Errors::UnknownRegistry, "Unknown registry '#{registry_id}'"
            end
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Boolean]
          def catalog_enabled?(registry_id)
            entry(registry_id).catalog
          end

          ##
          # @return [ConfigSnapshot]
          def current
            @mutex.synchronize { @current ||= parse_snapshot }
          end

          ##
          # Clears memoized configuration (tests and development reload).
          #
          # @return [nil]
          def reload!
            @mutex.synchronize { @current = nil }
            nil
          end

          private

          ##
          # @return [ConfigSnapshot]
          def parse_snapshot
            document = load_document
            precedence = Array(document[:precedence]).map(&:to_s)
            precedence = DEFAULT_PRECEDENCE if precedence.empty?

            entries = precedence.to_h { |registry_id| [registry_id, parse_entry(registry_id, document)] }
            missing = precedence - entries.keys
            raise Errors::ConfigError, "Missing registry definitions: #{missing.join(', ')}" unless missing.empty?

            ConfigSnapshot.new(precedence:, entries:)
          end

          ##
          # @return [Hash{Symbol => Object}]
          def load_document
            path = registries_file
            return default_document unless File.file?(path)

            YAML.safe_load_file(path, symbolize_names: true) || {}
          rescue Psych::SyntaxError => error
            raise Errors::ConfigError, "Invalid #{path}: #{error.message}"
          end

          ##
          # @return [String]
          def registries_file
            ENV.fetch('REGISTRIES_CONFIG', REGISTRIES_FILE)
          end

          ##
          # @return [Hash{Symbol => Object}]
          def default_document
            {
              precedence: DEFAULT_PRECEDENCE,
              registries: {
                'official' => {
                  sync: { channel: DEFAULT_OFFICIAL_SYNC_CHANNEL },
                  catalog: true
                }
              }
            }
          end

          ##
          # @param registry_id [String]
          # @param document [Hash{Symbol => Object}]
          # @return [Entry]
          def parse_entry(registry_id, document)
            raw = document.dig(:registries, registry_id.to_sym) ||
                  document.dig(:registries, registry_id)
            raise Errors::ConfigError, "Missing registry definition for '#{registry_id}'" unless raw.is_a?(Hash)

            build_entry(registry_id, raw)
          end

          ##
          # @param registry_id [String]
          # @param raw [Hash{Symbol => Object}]
          # @return [Entry]
          def build_entry(registry_id, raw)
            sync = sync_section(raw)
            mode, resolved_path, sync_channel, sync_url = resolve_mode(
              path: raw[:path]&.to_s,
              sync_channel: sync[:channel]&.to_s,
              sync_url: sync[:url]&.to_s
            )

            entry_attributes(registry_id, raw, mode, resolved_path, sync_channel, sync_url)
          end

          ##
          # @param registry_id [String]
          # @param raw [Hash{Symbol => Object}]
          # @param mode [Symbol]
          # @param path [String, nil]
          # @param sync_channel [String, nil]
          # @param sync_url [String, nil]
          # @return [Entry]
          def entry_attributes(registry_id, raw, mode, path, sync_channel, sync_url) # rubocop:disable Metrics/ParameterLists
            Entry.new(
              id: registry_id,
              mode:,
              path:,
              sync_channel:,
              sync_url:,
              catalog: raw.fetch(:catalog, true),
              public_key_id: public_key_id_for(raw[:public_key_id]&.to_s),
              public_key: parse_public_key(raw[:public_key])
            )
          end

          ##
          # @param raw [Hash{Symbol => Object}]
          # @return [Hash{Symbol => Object}]
          def sync_section(raw)
            raw[:sync].is_a?(Hash) ? raw[:sync] : {}
          end

          ##
          # @param public_key_id [String, nil]
          # @return [String]
          def public_key_id_for(public_key_id)
            return public_key_id if public_key_id && !public_key_id.empty?

            'html2rss:registry:2026'
          end

          ##
          # @param path [String, nil]
          # @param sync_channel [String, nil]
          # @param sync_url [String, nil]
          # @return [Array(Symbol, String, nil, String, nil)]
          def resolve_mode(path:, sync_channel:, sync_url:)
            return [:path, expand_path(path), nil, nil] if path && !path.empty?

            resolved_sync_url = sync_url && !sync_url.empty? ? sync_url : resolve_sync_channel_url(sync_channel)
            [:sync, nil, sync_channel, resolved_sync_url]
          end

          ##
          # @param sync_channel [String, nil]
          # @return [String]
          def resolve_sync_channel_url(sync_channel)
            channel = sync_channel && !sync_channel.empty? ? sync_channel : DEFAULT_OFFICIAL_SYNC_CHANNEL
            return OFFICIAL_RELEASE_URL if channel == DEFAULT_OFFICIAL_SYNC_CHANNEL

            raise Errors::ConfigError, "Unknown sync channel '#{channel}'"
          end

          ##
          # @param path [String]
          # @return [String]
          def expand_path(path)
            return path if path.start_with?('/')

            File.expand_path(path, Dir.pwd)
          end

          ##
          # @param value [String, nil]
          # @return [OpenSSL::PKey::PKey, nil]
          def parse_public_key(value)
            return nil if value.to_s.strip.empty?

            OpenSSL::PKey.read(value)
          rescue OpenSSL::PKey::PKeyError => error
            raise Errors::ConfigError, "Invalid registry public_key: #{error.message}"
          end
        end # rubocop:enable Metrics/ClassLength

        ##
        # Parsed registry configuration snapshot.
        ConfigSnapshot = Data.define(:precedence, :entries)
      end # rubocop:enable Metrics/ModuleLength
    end
  end
end
