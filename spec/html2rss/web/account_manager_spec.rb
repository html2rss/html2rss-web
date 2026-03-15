# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/security/account_manager'

RSpec.describe Html2rss::Web::AccountManager do
  describe '.get_account' do
    it 'returns account by token' do
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(
        auth: { accounts: [{ username: 'alice', token: 'token-1', allowed_urls: ['*'] }] }
      )

      account = described_class.get_account('token-1')

      expect(account).to include(username: 'alice', token: 'token-1')
    end
  end

  describe '.reload!' do
    it 'keeps memoized snapshot before reload' do
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(
        { auth: { accounts: [{ username: 'alice', token: 'token-1', allowed_urls: ['*'] }] } },
        { auth: { accounts: [{ username: 'bob', token: 'token-2', allowed_urls: ['*'] }] } }
      )

      described_class.get_account('token-1')
      expect(described_class.get_account('token-2')).to be_nil
    end

    it 'clears memoized snapshot after reload' do
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(
        { auth: { accounts: [{ username: 'alice', token: 'token-1', allowed_urls: ['*'] }] } },
        { auth: { accounts: [{ username: 'bob', token: 'token-2', allowed_urls: ['*'] }] } }
      )

      described_class.get_account('token-1')
      described_class.reload!
      expect(described_class.get_account('token-2')).to include(username: 'bob')
    end
  end

  describe '.get_account_by_username' do
    it 'returns account by username from the memoized snapshot' do
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(
        auth: { accounts: [{ username: 'alice', token: 'token-1', allowed_urls: ['*'] }] }
      )

      account = described_class.get_account_by_username('alice')

      expect(account).to include(username: 'alice', token: 'token-1')
    end
  end
end
