# frozen_string_literal: true

require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Account management functionality
    module AccountManager
      class << self
        def reload!
          nil
        end

        # @param token [String]
        # @return [Hash, nil]
        def get_account(token)
          return nil unless token

          token_index[token]
        end

        # @return [Array<Hash>]
        def accounts
          raw_accounts = LocalConfig.global.dig(:auth, :accounts)
          Array(raw_accounts).map { |account| account.transform_keys(&:to_sym).freeze }.freeze
        end

        # @param username [String]
        # @return [Hash, nil]
        def get_account_by_username(username)
          return nil unless username

          accounts.find { |account| account[:username] == username }
        end

        private

        def token_index
          accounts.each_with_object({}) { |account, hash| hash[account[:token]] = account }.freeze
        end
      end
    end
  end
end
