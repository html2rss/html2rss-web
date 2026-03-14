# frozen_string_literal: true

require_relative 'local_config'
require_relative 'security_logger'

module Html2rss
  module Web
    ##
    # Thread-safe account snapshot cache.
    #
    # Keeps config reads cheap by materializing one immutable snapshot and
    # exposing narrow lookup helpers for auth and authorization flows.
    module AccountManager
      class << self
        # Forces account snapshot refresh on next access.
        # Used by tests and can be used by runtime reload hooks.
        #
        # @param reason [String]
        # @return [nil]
        def reload!(reason: 'manual')
          @snapshot = nil # rubocop:disable ThreadSafety/ClassInstanceVariable
          SecurityLogger.log_cache_lifecycle('account_manager', 'reload', reason: reason)
          nil
        end

        # @param token [String]
        # @return [Hash{Symbol=>Object}, nil]
        def get_account(token)
          return nil unless token

          snapshot[:token_index][token]
        end

        # @return [Array<Hash{Symbol=>Object}>]
        def accounts
          snapshot[:accounts]
        end

        # @param username [String]
        # @return [Hash{Symbol=>Object}, nil]
        def get_account_by_username(username)
          return nil unless username

          accounts.find { |account| account[:username] == username }
        end

        private

        # Lazily initializes and memoizes an immutable account snapshot.
        #
        # @return [Hash{Symbol=>Object}]
        # @option return [Array<Hash{Symbol=>Object}>] :accounts frozen account list.
        # @option return [Hash{String=>Hash{Symbol=>Object}}] :token_index token lookup table.
        def snapshot
          return @snapshot if @snapshot # rubocop:disable ThreadSafety/ClassInstanceVariable

          mutex.synchronize do
            @snapshot ||= build_snapshot
          end
        end

        # @return [Mutex] synchronization primitive for snapshot rebuilds.
        def mutex
          @mutex ||= Mutex.new # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Builds the immutable account snapshot from local configuration.
        #
        # @return [Hash{Symbol=>Object}]
        # @option return [Array<Hash{Symbol=>Object}>] :accounts frozen account list.
        # @option return [Hash{String=>Hash{Symbol=>Object}}] :token_index token lookup table.
        def build_snapshot
          raw_accounts = LocalConfig.global.dig(:auth, :accounts)
          accounts = Array(raw_accounts).map { |account| account.transform_keys(&:to_sym).freeze }.freeze
          token_index = accounts.to_h { |account| [account[:token], account] }.freeze

          SecurityLogger.log_cache_lifecycle('account_manager', 'build', accounts_count: accounts.length)
          { accounts: accounts, token_index: token_index }.freeze
        end

        # @return [Hash{String=>Hash{Symbol=>Object}}]
        def token_index
          snapshot[:token_index]
        end
      end
    end
  end
end
