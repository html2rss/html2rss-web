# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Service do
  subject(:result) { described_class.call(resolved_source) }

  let(:resolved_source) do
    Html2rss::Web::Feeds::ResolvedSource.new(
      source_kind: :static,
      cache_identity: 'example-feed:abc123',
      generator_input: {
        strategy: :ssrf_filter,
        channel: { url: 'https://example.com/articles' },
        auto_source: {}
      },
      ttl_seconds: 900
    )
  end

  before do
    Html2rss::Web::Feeds::Cache.clear!
  end

  context 'when feed generation succeeds with items' do
    let(:feed) { Struct.new(:items).new([Object.new]) }

    before do
      allow(Html2rss).to receive(:feed).with(resolved_source.generator_input).and_return(feed)
    end

    it 'marks the result as ok' do
      expect(result.status).to eq(:ok)
    end

    it 'preserves the source ttl' do
      expect(result.ttl_seconds).to eq(900)
    end

    it 'uses the canonical source cache key' do
      expect(result.cache_key).to eq('feed_result:example-feed:abc123')
    end

    it 'retains the canonical payload metadata' do
      expect(result.payload).to eq(
        feed: feed,
        url: 'https://example.com/articles',
        strategy: 'ssrf_filter'
      )
    end

    it 'reuses the cached result for repeated requests' do
      described_class.call(resolved_source)
      described_class.call(resolved_source)

      expect(Html2rss).to have_received(:feed).once
    end
  end

  context 'when the generated feed has no items' do
    before do
      allow(Html2rss).to receive(:feed).with(resolved_source.generator_input).and_return(Struct.new(:items).new([]))
    end

    it 'marks the result as empty' do
      expect(result.status).to eq(:empty)
    end

    it 'keeps the result message empty' do
      expect(result.message).to be_nil
    end
  end

  context 'when generation fails' do
    before do
      allow(Html2rss).to receive(:feed).with(resolved_source.generator_input).and_raise(StandardError, 'boom')
    end

    it 'marks the result as an error' do
      expect(result.status).to eq(:error)
    end

    it 'returns the generator error message' do
      expect(result.message).to eq('boom')
    end

    it 'drops the feed payload' do
      expect(result.payload).to be_nil
    end
  end
end
