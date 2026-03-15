# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/feed_identity'

RSpec.describe Html2rss::Web::FeedIdentity do
  let(:attributes) do
    {
      name: 'Example Feed',
      url: 'https://example.com/articles',
      username: 'alice',
      strategy: 'ssrf_filter',
      feed_token: 'generated-token',
      identity_token: 'account-token'
    }
  end

  let(:expected_hash) do
    {
      id: described_class.stable_id('alice', 'https://example.com/articles', 'account-token'),
      name: 'Example Feed',
      url: 'https://example.com/articles',
      username: 'alice',
      strategy: 'ssrf_filter',
      feed_token: 'generated-token',
      public_url: '/api/v1/feeds/generated-token',
      json_public_url: '/api/v1/feeds/generated-token.json'
    }
  end

  describe '.metadata' do
    it 'builds stable feed metadata from domain identity inputs' do
      expect(described_class.metadata(attributes).to_h).to eq(expected_hash)
    end
  end
end
