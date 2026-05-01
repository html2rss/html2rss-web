# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Thread-safe account snapshot cache.
    #
    # Keeps config reads cheap by materializing one immutable snapshot and
    # exposing narrow lookup helpers for auth and authorization flows.
    module AccountManager
      @mutex = Mutex.new
      @snapshot = nil

      class << self
        # Forces account snapshot refresh on next access.
        #
        # @param reason [String]
        # @return [nil]
        def reload!(reason: 'manual')
          @mutex.synchronize { @snapshot = nil }
          SecurityLogger.log_cache_lifecycle('account_manager', 'reload', reason: reason)
          nil
        end

        # @param token [String, nil]
        # @return [Hash{Symbol=>Object}, nil]
        def get_account(token)
          return nil unless token

          snapshot[:token_index][token]
        end

        # @return [Array<Hash{Symbol=>Object}>]
        def accounts
          snapshot[:accounts]
        end

        # @param username [String, nil]
        # @return [Hash{Symbol=>Object}, nil]
        def get_account_by_username(username)
          return nil unless username

          snapshot[:username_index][username]
        end

        private

        def snapshot
          @mutex.synchronize { @snapshot ||= build_snapshot }
        end

        def build_snapshot
          raw_accounts = LocalConfig.global.dig(:auth, :accounts)
          accounts = normalized_accounts(raw_accounts)
          token_index = index_accounts(accounts, :token)
          username_index = index_accounts(accounts, :username)

          SecurityLogger.log_cache_lifecycle('account_manager', 'build', accounts_count: accounts.length)
          { accounts: accounts, token_index: token_index, username_index: username_index }.freeze
        end

        # @param raw_accounts [Array<Hash>, nil]
        # @return [Array<Hash{Symbol=>Object}>]
        def normalized_accounts(raw_accounts)
          Array(raw_accounts).map { |account| account.transform_keys(&:to_sym).freeze }.freeze
        end

        # @param accounts [Array<Hash{Symbol=>Object}>]
        # @param key [Symbol]
        # @return [Hash{Object=>Hash{Symbol=>Object}}]
        def index_accounts(accounts, key)
          accounts.to_h { |account| [account[key], account] }.freeze
        end
      end
    end
  end
end
