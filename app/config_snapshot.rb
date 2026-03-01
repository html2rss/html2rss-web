# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Typed immutable snapshot built from feeds YAML.
    #
    # This keeps parsing/validation in one place while letting runtime callers
    # progressively migrate away from dynamic hash contracts.
    module ConfigSnapshot
      ##
      # Immutable stylesheet entry model.
      StylesheetEntry = Data.define(:href, :media, :type)
      ##
      # Immutable auth account model.
      AuthAccount = Data.define(:username, :token, :allowed_urls)
      ##
      # Immutable feed config boundary model.
      FeedConfig = Data.define(:name, :raw)
      ##
      # Immutable root snapshot model.
      Snapshot = Data.define(:global, :feeds, :accounts)

      class << self
        # @param yaml_hash [Hash{Symbol=>Object}]
        # @return [Snapshot]
        def load(yaml_hash)
          raise ArgumentError, 'Configuration root must be a hash' unless yaml_hash.is_a?(Hash)

          feeds_hash = normalize_feeds(yaml_hash.fetch(:feeds, {}))
          global_hash = yaml_hash.reject { |key| key == :feeds }
          accounts = normalize_accounts(global_hash.dig(:auth, :accounts))
          normalized_global = normalized_global_hash(global_hash, accounts)

          Snapshot.new(
            global: normalized_global.freeze,
            feeds: feeds_hash.freeze,
            accounts: accounts.freeze
          )
        end

        private

        # @param raw_feeds [Hash, Object]
        # @return [Hash{Symbol=>FeedConfig}]
        def normalize_feeds(raw_feeds)
          return {} unless raw_feeds.is_a?(Hash)

          raw_feeds.each_with_object({}) do |(name, config), memo|
            memo[name.to_sym] = FeedConfig.new(name: name.to_sym, raw: deep_dup(config).freeze)
          end
        end

        # @param raw_accounts [Array<Hash>, Object]
        # @return [Array<AuthAccount>]
        def normalize_accounts(raw_accounts)
          Array(raw_accounts).map do |account|
            account_hash = account.to_h.transform_keys(&:to_sym)
            AuthAccount.new(
              username: account_hash.fetch(:username).to_s,
              token: account_hash.fetch(:token).to_s,
              allowed_urls: Array(account_hash[:allowed_urls]).map(&:to_s).freeze
            )
          end
        end

        # @param global_hash [Hash{Symbol=>Object}]
        # @param accounts [Array<AuthAccount>]
        # @return [Hash{Symbol=>Object}]
        def normalized_global_hash(global_hash, accounts)
          normalized = deep_dup(global_hash)
          return normalized unless normalized.key?(:auth)

          normalized[:auth] = normalized_auth_hash(normalized[:auth], accounts)
          normalized
        end

        # @param auth_hash [Hash, Object]
        # @param accounts [Array<AuthAccount>]
        # @return [Hash{Symbol=>Object}]
        def normalized_auth_hash(auth_hash, accounts)
          auth = auth_hash.to_h
          auth[:accounts] = accounts.map do |account|
            { username: account.username, token: account.token, allowed_urls: account.allowed_urls.dup }
          end
          auth
        end

        # @param value [Object]
        # @return [Object]
        def deep_dup(value)
          case value
          when Hash
            deep_dup_hash(value)
          when Array
            deep_dup_array(value)
          when String
            value.dup
          else
            value
          end
        end

        # @param value [Hash]
        # @return [Hash]
        def deep_dup_hash(value)
          value.each_with_object({}) do |(key, val), memo|
            memo[key.is_a?(String) ? key.dup : key] = deep_dup(val)
          end
        end

        # @param value [Array]
        # @return [Array]
        def deep_dup_array(value)
          value.map { |element| deep_dup(element) }
        end
      end
    end
  end
end
