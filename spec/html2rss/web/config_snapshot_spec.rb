# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::ConfigSnapshot do
  let(:yaml) do
    {
      stylesheets: [{ href: 'a.css' }],
      auth: { accounts: [{ 'username' => 'alice', 'token' => 123, 'allowed_urls' => ['*', :sym] }], extra: 1 },
      feeds: { 'news' => { channel: { url: 'https://example.com' } }, other: { x: 1 } }
    }
  end

  describe '.load' do
    it 'rejects non-hash roots', :aggregate_failures do
      expect { described_class.load([]) }.to raise_error(ArgumentError, 'Configuration root must be a hash')
      expect { described_class.load(nil) }.to raise_error(ArgumentError)
    end

    it 'builds frozen feeds keyed by symbol', :aggregate_failures do
      snapshot = described_class.load(yaml)

      expect(snapshot.feeds.keys).to eq(%i[news other])
      expect(snapshot.feeds[:news]).to have_attributes(name: :news, raw: { channel: { url: 'https://example.com' } })
      expect(snapshot.feeds).to be_frozen
      expect(snapshot.feeds[:news].raw).to be_frozen
    end

    it 'ignores non-hash feeds and tolerates a missing feeds key', :aggregate_failures do
      expect(described_class.load({ feeds: 'nope' }).feeds).to eq({})
      expect(described_class.load({}).feeds).to eq({})
    end

    it 'keeps everything except feeds in the frozen global hash', :aggregate_failures do
      global = described_class.load(yaml).global

      expect(global).to be_frozen
      expect(global).not_to have_key(:feeds)
      expect(global[:stylesheets]).to eq([{ href: 'a.css' }])
    end

    it 'normalizes accounts to strings with frozen url lists', :aggregate_failures do
      account = described_class.load(yaml).accounts.first

      expect(account).to have_attributes(username: 'alice', token: '123', allowed_urls: %w[* sym])
      expect(account.allowed_urls).to be_frozen
    end

    it 'defaults allowed_urls to an empty list and requires username and token', :aggregate_failures do
      account = described_class.load({ auth: { accounts: [{ username: 'a', token: 'b' }] } }).accounts.first

      expect(account.allowed_urls).to eq([])
      expect { described_class.load({ auth: { accounts: [{ token: 'b' }] } }) }.to raise_error(KeyError)
      expect { described_class.load({ auth: { accounts: [{ username: 'a' }] } }) }.to raise_error(KeyError)
    end

    it 'has no accounts without auth config', :aggregate_failures do
      snapshot = described_class.load({})

      expect(snapshot.accounts).to eq([])
      expect(snapshot.accounts).to be_frozen
      expect(snapshot.global).not_to have_key(:auth)
    end

    it 'rewrites global auth accounts with normalized, independent values', :aggregate_failures do
      snapshot = described_class.load(yaml)
      auth = snapshot.global[:auth]

      expect(auth[:extra]).to eq(1)
      expect(auth[:accounts]).to eq([{ username: 'alice', token: '123', allowed_urls: %w[* sym] }])
      expect(auth[:accounts].first[:allowed_urls]).not_to equal(snapshot.accounts.first.allowed_urls)
    end

    it 'does not share structure with the input', :aggregate_failures do
      snapshot = described_class.load(yaml)

      expect(snapshot.feeds[:news].raw).not_to equal(yaml[:feeds]['news'])
      expect(snapshot.feeds[:news].raw[:channel]).not_to equal(yaml[:feeds]['news'][:channel])
      expect(snapshot.global[:stylesheets]).not_to equal(yaml[:stylesheets])
    end
  end

  describe '.deep_dup' do
    it 'duplicates nested hashes, arrays and strings', :aggregate_failures do
      original = { 'k' => ['v', { n: 'x' }] }
      copy = described_class.deep_dup(original)

      expect(copy).to eq(original)
      expect(copy['k']).not_to equal(original['k'])
      expect(copy['k'][0]).not_to equal(original['k'][0])
      expect(copy['k'][1][:n]).not_to equal(original['k'][1][:n])
    end

    it 'returns other values untouched', :aggregate_failures do
      sym = :sym
      expect(described_class.deep_dup(sym)).to equal(sym)
      expect(described_class.deep_dup(5)).to eq(5)
      expect(described_class.deep_dup(nil)).to be_nil
    end

    it 'keeps symbol keys as they are' do
      expect(described_class.deep_dup({ a: 1 }).keys).to eq([:a])
    end
  end
end
