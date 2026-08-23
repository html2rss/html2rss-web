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
      module Config
        REGISTRIES_FILE = 'config/registries.yml'
        DEFAULT_PRECEDENCE = %w[official].freeze
        DEFAULT_OFFICIAL_SYNC_CHANNEL = 'html2rss-official'
        OFFICIAL_RELEASE_URL = 'https://github.com/html2rss/html2rss-configs/releases/latest/download/registry-bundle.tar.gz'
        DEFAULT_PUBLIC_KEY_PEM = <<~PEM
          -----BEGIN PUBLIC KEY-----
          MCowBQYDK2VwAyEAiMbg/04MyC5azBdM/aeY0mNuA8JbP5/jOiNRwJ2KJHE=
          -----END PUBLIC KEY-----
        PEM

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
          def parse_document # rubocop:disable Metrics/CyclomaticComplexity
            raw_doc = load_yaml
            precedence = Array(raw_doc[:precedence]).map(&:to_s).reject(&:empty?)
            precedence = DEFAULT_PRECEDENCE if precedence.empty?
            registries = raw_doc[:registries] || {}

            entries = precedence.to_h do |id|
              raw = registries[id.to_sym] || registries[id] || {}
              [id, build_definition(id, raw)]
            end

            Document.new(precedence:, entries:)
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
            sync = raw[:sync].is_a?(Hash) ? raw[:sync] : {}
            path = raw[:path]&.to_s
            mode = path && !path.empty? ? :path : :sync
            key_pem = raw[:public_key]&.to_s
            key = key_pem && !key_pem.strip.empty? ? parse_key(key_pem) : nil

            definition = Definition.new(
              id:,
              mode:,
              path: mode == :path ? File.expand_path(path, Dir.pwd) : nil,
              sync_channel: sync[:channel]&.to_s || DEFAULT_OFFICIAL_SYNC_CHANNEL,
              sync_url: sync[:url]&.to_s,
              catalog: raw.fetch(:catalog, true),
              public_key_id: raw[:public_key_id]&.to_s || 'html2rss:registry:2026',
              public_key: key,
              sync_policy: SyncPolicy.new(
                pin_version: sync[:pin_version]&.to_s,
                max_version: sync[:max_version]&.to_s,
                auto_promote: raw[:auto_promote] == true
              ),
              allowed_channel_domains: Array(raw[:allowed_channel_domains]).map(&:to_s).reject(&:empty?)
            )

            if definition.mode == :sync && definition.public_key.nil?
              raise Errors::ConfigError, "Sync registry '#{id}' requires a pinned public_key"
            end

            definition
          end

          ##
          # @param pem [String]
          # @return [OpenSSL::PKey::PKey]
          def parse_key(pem)
            OpenSSL::PKey.read(pem)
          rescue OpenSSL::PKey::PKeyError => error
            raise Errors::ConfigError, "Invalid registry public_key: #{error.message}"
          end
        end
      end
    end
  end
end
