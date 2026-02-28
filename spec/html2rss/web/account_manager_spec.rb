# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/account_manager'

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
    it 'is a compatibility no-op that keeps interface stable' do
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(
        auth: { accounts: [{ username: 'alice', token: 'token-1', allowed_urls: ['*'] }] }
      )

      expect(described_class.reload!).to be_nil
    end
  end
end
