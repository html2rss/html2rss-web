# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::AccountManager do
  let(:raw) { [{ 'username' => 'alice', 'token' => 't1', 'allowed_urls' => ['*'] }, { username: 'bob', token: 't2' }] }
  let(:tokenless) { { auth: { accounts: [{ allowed_urls: ['*'] }] } } }

  before do
    described_class.reload!
    allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(auth: { accounts: raw })
    allow(Html2rss::Web::Observability).to receive(:emit)
  end

  after { described_class.reload! }

  describe '.get_account' do
    it 'returns the account indexed by token', :aggregate_failures do
      expect(described_class.get_account('t1')).to include(username: 'alice', token: 't1')
      expect(described_class.get_account('t2')).to include(username: 'bob')
    end

    it 'does not resolve usernames or unknown tokens', :aggregate_failures do
      expect(described_class.get_account('bob')).to be_nil
      expect(described_class.get_account('nope')).to be_nil
    end

    it 'never resolves nil to an account lacking a token' do
      described_class.reload!
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(tokenless)

      expect(described_class.get_account(nil)).to be_nil
    end

    it 'does not build a snapshot for nil tokens' do
      described_class.get_account(nil)

      expect(Html2rss::Web::LocalConfig).not_to have_received(:global)
    end

    it 'handles missing auth config' do
      described_class.reload!
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return({})

      expect(described_class.get_account('t1')).to be_nil
    end
  end

  describe '.accounts' do
    it 'symbolizes keys and freezes the list and its accounts', :aggregate_failures do
      expect(described_class.accounts.map { |a| a[:username] }).to eq(%w[alice bob])
      expect(described_class.accounts).to be_frozen
      expect(described_class.accounts).to all(be_frozen)
    end

    it 'is empty without auth config' do
      described_class.reload!
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return({})

      expect(described_class.accounts).to eq([])
    end

    it 'builds the snapshot once and emits a build event', :aggregate_failures do
      2.times { described_class.accounts }

      expect(Html2rss::Web::LocalConfig).to have_received(:global).once
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'cache.lifecycle', outcome: 'success',
        details: { component: 'account_manager', event: 'build', accounts_count: 2 }, level: :info
      ).once
    end

    it 'freezes the token and username indexes', :aggregate_failures do
      snapshot = described_class.send(:snapshot)

      expect(snapshot.token_index).to be_frozen
      expect(snapshot.username_index).to be_frozen
    end
  end

  describe '.get_account_by_username' do
    it 'returns the account indexed by username', :aggregate_failures do
      expect(described_class.get_account_by_username('bob')).to include(token: 't2')
      expect(described_class.get_account_by_username('t1')).to be_nil
    end

    it 'never resolves nil to an account lacking a username' do
      described_class.reload!
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(tokenless)

      expect(described_class.get_account_by_username(nil)).to be_nil
    end

    it 'does not build a snapshot for nil usernames' do
      described_class.get_account_by_username(nil)

      expect(Html2rss::Web::LocalConfig).not_to have_received(:global)
    end
  end

  describe '.reload!' do
    it 'keeps the memoized snapshot until reloaded', :aggregate_failures do
      allow(Html2rss::Web::LocalConfig).to receive(:global).and_return(
        { auth: { accounts: [{ username: 'alice', token: 'token-1' }] } },
        { auth: { accounts: [{ username: 'bob', token: 'token-2' }] } }
      )

      described_class.get_account('token-1')
      expect(described_class.get_account('token-2')).to be_nil
      described_class.reload!
      expect(described_class.get_account('token-2')).to include(username: 'bob')
    end

    it 'returns nil and emits a reload event with the default reason', :aggregate_failures do
      expect(described_class.reload!).to be_nil
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'cache.lifecycle', outcome: 'success',
        details: { component: 'account_manager', event: 'reload', reason: 'manual' }, level: :info
      )
    end

    it 'passes a custom reason' do
      described_class.reload!(reason: 'test')

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        hash_including(details: { component: 'account_manager', event: 'reload', reason: 'test' })
      )
    end
  end
end
