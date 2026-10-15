# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Thread-safe account snapshot cache built from RuntimeEnv tokens.
    #
    # Admin always exists (full URL access). Health-check exists only when
    # +HEALTH_CHECK_TOKEN+ is set to a non-placeholder value.
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
          Observability.emit(
            event_name: 'cache.lifecycle',
            outcome: 'success',
            details: { component: 'account_manager', event: 'reload', reason: }
          )
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
          accounts = build_accounts
          token_index = index_accounts(accounts, :token)
          username_index = index_accounts(accounts, :username)

          Observability.emit(
            event_name: 'cache.lifecycle',
            outcome: 'success',
            details: { component: 'account_manager', event: 'build', accounts_count: accounts.length }
          )
          { accounts: accounts, token_index: token_index, username_index: username_index }.freeze
        end

        # @return [Array<Hash{Symbol=>Object}>]
        def build_accounts
          accounts = [admin_account]
          health = health_check_account
          accounts << health if health
          accounts.freeze
        end

        # @return [Hash{Symbol=>Object}]
        def admin_account
          {
            username: 'admin',
            token: RuntimeEnv.admin_access_token,
            allowed_urls: ['*'].freeze
          }.freeze
        end

        # @return [Hash{Symbol=>Object}, nil]
        def health_check_account
          token = RuntimeEnv.health_check_token
          return nil if token == RuntimeEnv::HEALTH_CHECK_TOKEN_PLACEHOLDER

          {
            username: 'health-check',
            token:,
            allowed_urls: [].freeze
          }.freeze
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
