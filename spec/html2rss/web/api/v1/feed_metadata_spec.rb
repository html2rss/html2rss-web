# frozen_string_literal: true

require 'spec_helper'
require 'digest'

require_relative '../../../../../app'

RSpec.describe Html2rss::Web::Api::V1::FeedMetadata do
  let(:attributes) do
    {
      name: 'Example Feed',
      url: 'https://example.com/articles',
      username: 'alice',
      strategy: 'faraday',
      feed_token: 'generated-token',
      identity_token: 'account-token'
    }
  end

  let(:expected_hash) do
    {
      id: Digest::SHA256.hexdigest('alice:https://example.com/articles:account-token')[0..15],
      name: 'Example Feed',
      url: 'https://example.com/articles',
      username: 'alice',
      strategy: 'faraday',
      feed_token: 'generated-token',
      public_url: '/api/v1/feeds/generated-token',
      json_public_url: '/api/v1/feeds/generated-token.json'
    }
  end

  describe '.build' do
    it 'builds stable feed metadata from creation attributes' do
      expect(described_class.build(attributes).to_h).to eq(expected_hash)
    end
  end
end
