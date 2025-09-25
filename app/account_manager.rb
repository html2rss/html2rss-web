# frozen_string_literal: true

require_relative 'local_config'

module Html2rss
  module Web
    ##
    # Account management functionality
    module AccountManager
      module_function

      # @param token [String]
      # @return [Hash, nil]
      def get_account(token)
        return nil unless token && token_index.key?(token)

        token_index[token]
      end

      # @return [Hash] token to account mapping
      def token_index
        @token_index ||= build_token_index # rubocop:disable ThreadSafety/ClassInstanceVariable
      end

      # @return [Hash]
      def build_token_index
        accounts.each_with_object({}) { |account, hash| hash[account[:token]] = account }
      end

      # @return [Array<Hash>]
      def accounts
        auth_config = LocalConfig.global[:auth]
        return [] unless auth_config&.dig(:accounts)

        auth_config[:accounts].map do |account|
          {
            username: account[:username].to_s,
            token: account[:token].to_s,
            allowed_urls: Array(account[:allowed_urls]).map(&:to_s)
          }
        end
      end

      # @param username [String]
      # @return [Hash, nil]
      def get_account_by_username(username)
        return nil unless username

        accounts.find { |account| account[:username] == username }
      end
    end
  end
end
