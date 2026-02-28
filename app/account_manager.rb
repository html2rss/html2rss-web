# frozen_string_literal: true

require_relative 'local_config'
require_relative 'security_logger'

module Html2rss
  module Web
    ##
    # Account management functionality
    module AccountManager
      class << self
        # Forces account snapshot refresh on next access.
        # Used by tests and can be used by runtime reload hooks.
        def reload!(reason: 'manual')
          @snapshot = nil # rubocop:disable ThreadSafety/ClassInstanceVariable
          SecurityLogger.log_cache_lifecycle('account_manager', 'reload', reason: reason)
          nil
        end

        # @param token [String]
        # @return [Hash, nil]
        def get_account(token)
          return nil unless token

          snapshot[:token_index][token]
        end

        # @return [Array<Hash>]
        def accounts
          snapshot[:accounts]
        end

        # @param username [String]
        # @return [Hash, nil]
        def get_account_by_username(username)
          return nil unless username

          accounts.find { |account| account[:username] == username }
        end

        private

        def snapshot
          return @snapshot if @snapshot # rubocop:disable ThreadSafety/ClassInstanceVariable

          mutex.synchronize do
            @snapshot ||= build_snapshot
          end
        end

        def mutex
          @mutex ||= Mutex.new # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        def build_snapshot
          raw_accounts = LocalConfig.global.dig(:auth, :accounts)
          accounts = Array(raw_accounts).map { |account| account.transform_keys(&:to_sym).freeze }.freeze
          token_index = accounts.each_with_object({}) { |account, hash| hash[account[:token]] = account }.freeze

          SecurityLogger.log_cache_lifecycle('account_manager', 'build', accounts_count: accounts.length)
          { accounts: accounts, token_index: token_index }.freeze
        end

        def token_index
          snapshot[:token_index]
        end
      end
    end
  end
end
