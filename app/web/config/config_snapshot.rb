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
            sym_name = name.to_sym
            memo[sym_name] = FeedConfig.new(name: sym_name, raw: StructuredData.deep_dup(config).freeze)
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
          normalized = StructuredData.deep_dup(global_hash)
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
      end
    end
  end
end
