# frozen_string_literal: true

require 'yaml'
require 'openssl'

module Html2rss
  module Web
    module Registry
      ##
      # Sync policy parsed from registry YAML.
      SyncPolicy = Data.define(:pin_version, :max_version, :auto_promote)

      ##
      # Registry definition parsed from {Config::REGISTRIES_FILE}.
      Definition = Data.define(
        :id,
        :mode,
        :path,
        :sync_channel,
        :sync_url,
        :catalog,
        :public_key_id,
        :public_key,
        :sync_policy,
        :allowed_channel_domains
      ) do
        ##
        # @return [Hash{String => OpenSSL::PKey::PKey}]
        def public_keys
          public_key ? { public_key_id => public_key } : {}
        end
      end

      ##
      # Parses registry configuration and applies zero-config defaults.
      module Config # rubocop:disable Metrics/ModuleLength
        REGISTRIES_FILE = 'config/registries.yml'
        DEFAULT_PRECEDENCE = %w[official].freeze
        DEFAULT_OFFICIAL_SYNC_CHANNEL = 'html2rss-official'
        OFFICIAL_RELEASE_URL = 'https://github.com/html2rss/html2rss-configs/releases/latest/download/registry-bundle.tar.gz'
        DEFAULT_PUBLIC_KEY_PEM = <<~PEM
          -----BEGIN PUBLIC KEY-----
          MCowBQYDK2VwAyEAiMbg/04MyC5azBdM/aeY0mNuA8JbP5/jOiNRwJ2KJHE=
          -----END PUBLIC KEY-----
        PEM

        ##
        # Registry configuration document containing precedence order and registry definitions.
        Document = Data.define(:precedence, :entries)

        @mutex = Mutex.new
        @current = nil

        class << self
          ##
          # @return [Array<String>]
          def precedence
            current.precedence
          end

          ##
          # @param registry_id [String, Symbol]
          # @return [Definition]
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
          # @return [Document]
          def current
            @mutex.synchronize { @current ||= parse_document }
          end

          ##
          # @return [nil]
          def reload!
            @mutex.synchronize { @current = nil }
            nil
          end

          private

          ##
          # @return [Document]
          def parse_document
            raw_doc = load_yaml
            precedence = parse_precedence(raw_doc[:precedence])
            registries = raw_doc[:registries] || {}

            entries = precedence.to_h do |id|
              raw = registries[id.to_sym] || registries[id] || {}
              [id, build_definition(id, raw)]
            end

            Document.new(precedence:, entries:)
          end

          def parse_precedence(raw_precedence)
            list = Array(raw_precedence).map(&:to_s).reject(&:empty?)
            list.empty? ? DEFAULT_PRECEDENCE : list
          end

          ##
          # @return [Hash{Symbol => Object}]
          def load_yaml
            path = ENV.fetch('REGISTRIES_CONFIG', REGISTRIES_FILE)
            return default_document unless File.file?(path)

            YAML.safe_load_file(path, symbolize_names: true) || {}
          rescue Psych::SyntaxError => error
            raise Errors::ConfigError, "Invalid #{path}: #{error.message}"
          end

          ##
          # @return [Hash{Symbol => Object}]
          def default_document # rubocop:disable Metrics/MethodLength
            {
              precedence: DEFAULT_PRECEDENCE,
              registries: {
                'official' => {
                  sync: { channel: DEFAULT_OFFICIAL_SYNC_CHANNEL },
                  catalog: true,
                  public_key_id: 'html2rss:registry:2026',
                  public_key: DEFAULT_PUBLIC_KEY_PEM
                }
              }
            }
          end

          ##
          # @param id [String]
          # @param raw [Hash{Symbol => Object}]
          # @return [Definition]
          def build_definition(id, raw) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
            sync_raw = raw[:sync]
            sync = sync_raw.is_a?(Hash) ? sync_raw : {}
            path = raw[:path]&.to_s
            mode = path && !path.empty? ? :path : :sync
            public_key = parse_public_key(raw[:public_key]&.to_s)

            definition = Definition.new(
              id:,
              mode:,
              path: mode == :path ? File.expand_path(path, Dir.pwd) : nil,
              sync_channel: sync[:channel]&.to_s || DEFAULT_OFFICIAL_SYNC_CHANNEL,
              sync_url: sync[:url]&.to_s,
              catalog: raw.fetch(:catalog, true),
              public_key_id: raw[:public_key_id]&.to_s || 'html2rss:registry:2026',
              public_key:,
              sync_policy: build_sync_policy(sync, raw),
              allowed_channel_domains: Array(raw[:allowed_channel_domains]).map(&:to_s).reject(&:empty?)
            )

            if definition.mode == :sync && !definition.public_key
              raise Errors::ConfigError, "Sync registry '#{id}' requires a pinned public_key"
            end

            definition
          end

          ##
          # @param sync [Hash{Symbol => Object}]
          # @param raw [Hash{Symbol => Object}]
          # @return [SyncPolicy]
          def build_sync_policy(sync, raw)
            SyncPolicy.new(
              pin_version: sync[:pin_version]&.to_s,
              max_version: sync[:max_version]&.to_s,
              auto_promote: raw[:auto_promote] == true
            )
          end

          ##
          # @param key_pem [String, nil]
          # @return [OpenSSL::PKey::PKey, nil]
          def parse_public_key(key_pem)
            return nil if key_pem.to_s.strip.empty?

            OpenSSL::PKey.read(key_pem)
          rescue OpenSSL::PKey::PKeyError => error
            raise Errors::ConfigError, "Invalid registry public_key: #{error.message}"
          end
        end
      end
    end
  end
end
