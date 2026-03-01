# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/feed_runtime'

RSpec.describe Html2rss::Web::FeedRuntime do
  before do
    described_class.clear!
  end

  it 'bypasses cache when async refresh is disabled' do
    expect(read_twice(key: 'k1', async_refresh: false)).to eq(%w[v1 v2])
  end

  it 'returns cached content when async refresh is enabled' do
    expect(read_twice(key: 'k2', async_refresh: true)).to eq(%w[v1 v1])
  end

  private

  # @param key [String]
  # @param async_refresh [Boolean]
  # @return [Array<String>]
  def read_twice(key:, async_refresh:)
    value = 0
    content = lambda do
      value += 1
      "v#{value}"
    end

    [
      described_class.read(key: key, ttl_seconds: 60, async_refresh: async_refresh, &content),
      described_class.read(key: key, ttl_seconds: 60, async_refresh: async_refresh, &content)
    ]
  end
end
