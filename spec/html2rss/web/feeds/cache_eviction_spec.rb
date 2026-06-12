# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

# rubocop:disable RSpec/ExampleLength
RSpec.describe 'Cache Eviction' do
  let(:cache) { Html2rss::Web::Feeds::Cache }

  before do
    cache.clear!
  end

  def build_result(title)
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(
        feed: Object.new, site_title: title, url: 'https://example.com', strategy: 'faraday'
      ),
      message: nil, ttl_seconds: 60, cache_key: "feed_result:#{title}", error_message: nil, error_kind: nil
    )
  end

  it 'respects the max size and evicts expiring soonest when exceeded', :aggregate_failures do
    allow(Html2rss::Web::Flags).to receive(:feeds_cache_max_size).and_return(3)

    cache.fetch('key1', ttl_seconds: 10) { build_result('one') }
    cache.fetch('key2', ttl_seconds: 20) { build_result('two') }
    cache.fetch('key3', ttl_seconds: 30) { build_result('three') }

    # Writing 4th entry triggers eviction. Target size: 2.
    cache.fetch('key4', ttl_seconds: 40) { build_result('four') }

    allow(Html2rss::Web::Flags).to receive(:feeds_cache_max_size).and_return(10)

    # Verify key1 is evicted (yields on next fetch)
    yielded_key1 = false
    cache.fetch('key1', ttl_seconds: 10) { yielded_key1 = true; build_result('one') } # rubocop:disable Style/Semicolon
    expect(yielded_key1).to be(true)

    # Verify key2, key3, and key4 are still cached
    yielded_key2 = false
    cache.fetch('key2', ttl_seconds: 20) { yielded_key2 = true; build_result('two') } # rubocop:disable Style/Semicolon
    expect(yielded_key2).to be(false)

    yielded_key3 = false
    cache.fetch('key3', ttl_seconds: 30) { yielded_key3 = true; build_result('three') } # rubocop:disable Style/Semicolon
    expect(yielded_key3).to be(false)

    yielded_key4 = false
    cache.fetch('key4', ttl_seconds: 40) { yielded_key4 = true; build_result('four') } # rubocop:disable Style/Semicolon
    expect(yielded_key4).to be(false)
  end

  it 'prunes expired entries first', :aggregate_failures do
    allow(Html2rss::Web::Flags).to receive(:feeds_cache_max_size).and_return(3)

    base_time = Time.now.utc
    allow(Time).to receive(:now).and_return(base_time)

    cache.fetch('key1', ttl_seconds: 10) { build_result('one') }
    cache.fetch('key2', ttl_seconds: 20) { build_result('two') }
    cache.fetch('key3', ttl_seconds: 30) { build_result('three') }

    allow(Time).to receive(:now).and_return(base_time + 15)

    # Write 4th entry. First pass deletes 'key1' (expired). Size is 2 (< 3), no other evictions.
    cache.fetch('key4', ttl_seconds: 40) { build_result('four') }

    allow(Html2rss::Web::Flags).to receive(:feeds_cache_max_size).and_return(10)

    # Verify key1 yields (expired/evicted)
    yielded_key1 = false
    cache.fetch('key1', ttl_seconds: 10) { yielded_key1 = true; build_result('one') } # rubocop:disable Style/Semicolon
    expect(yielded_key1).to be(true)

    # Verify key2 and key3 are still cached
    yielded_key2 = false
    cache.fetch('key2', ttl_seconds: 20) { yielded_key2 = true; build_result('two') } # rubocop:disable Style/Semicolon
    expect(yielded_key2).to be(false)

    yielded_key3 = false
    cache.fetch('key3', ttl_seconds: 30) { yielded_key3 = true; build_result('three') } # rubocop:disable Style/Semicolon
    expect(yielded_key3).to be(false)
  end
end
# rubocop:enable RSpec/ExampleLength
