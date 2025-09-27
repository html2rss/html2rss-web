# frozen_string_literal: true

require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Account management functionality
    module AccountManager
      class << self
        # @param token [String]
        # @return [Hash, nil]
        def get_account(token)
          return nil unless token && token_index.key?(token)

          token_index[token]
        end

        # @return [Array<Hash>]
        def accounts
          @accounts ||= begin # rubocop:disable ThreadSafety/ClassInstanceVariable
            auth_config = LocalConfig.global[:auth]
            raw_accounts = auth_config&.dig(:accounts)

            Array(raw_accounts).map { |account| account.transform_keys(&:to_sym) }
          end
        end

        # @param username [String]
        # @return [Hash, nil]
        def get_account_by_username(username)
          return nil unless username

          accounts.find { |account| account[:username] == username }
        end

        private

        # @return [Hash] token to account mapping
        def token_index
          @token_index ||= accounts.each_with_object({}) { |account, hash| hash[account[:token]] = account } # rubocop:disable ThreadSafety/ClassInstanceVariable
        end
      end
    end
  end
end
