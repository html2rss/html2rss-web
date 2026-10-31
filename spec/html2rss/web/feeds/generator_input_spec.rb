# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Feeds::GeneratorInput do
  let(:url) { 'https://example.com/feed' }

  before do
    allow(Html2rss::RequestService).to receive(:strategy_names).and_return(%i[auto default faraday])
    allow(Html2rss::Web::LocalConfig).to receive(:global)
      .and_return({ headers: { 'User-Agent' => 'html2rss-web' }, stylesheets: [], ignored: true })
  end

  describe '.for_token' do
    it 'keeps auto_source without selectors', :aggregate_failures do
      config = described_class.for_token(url:, strategy: 'default')

      expect(config).to eq(
        headers: { 'User-Agent' => 'html2rss-web' }, stylesheets: [],
        channel: { url: }, strategy: :default, auto_source: {}
      )
    end

    it 'replaces auto_source with the signed selectors', :aggregate_failures do
      selectors = { items: { selector: 'article' } }
      config = described_class.for_token(url:, selectors:)

      expect(config).to include(selectors:)
      expect(config).not_to have_key(:auto_source)
    end

    it 'resolves nil and blank strategies to the configured default' do
      allow(Html2rss::Config).to receive(:default_strategy_name).and_return(:faraday)

      expect([nil, ' '].map { described_class.for_token(url:, strategy: it)[:strategy] }).to eq(%i[faraday faraday])
    end

    it 'falls back to auto when the configured default is blank' do
      allow(Html2rss::Config).to receive(:default_strategy_name).and_return('')

      expect(described_class.for_token(url:)[:strategy]).to eq(:auto)
    end

    it 'trims surrounding whitespace from explicit strategies' do
      expect(described_class.for_token(url:, strategy: ' faraday ')[:strategy]).to eq(:faraday)
    end

    it 'accepts the configured default even when it is not a registered strategy' do
      allow(Html2rss::Config).to receive(:default_strategy_name).and_return(:legacy)

      expect(described_class.for_token(url:, strategy: 'legacy')[:strategy]).to eq(:legacy)
    end

    it 'rejects unsupported strategies' do
      expect { described_class.for_token(url:, strategy: 'nope') }
        .to raise_error(Html2rss::Web::BadRequestError, 'Unsupported strategy')
    end
  end
end
