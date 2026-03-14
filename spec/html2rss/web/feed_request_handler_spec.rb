# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::FeedRequestHandler do
  describe '.call' do
    let(:feed_name) { 'legacy' }
    let(:params) { { 'page' => '1', 'sort' => 'recent' } }

    before do
      allow(Html2rss::Web::LocalConfig).to receive(:find).with(feed_name).and_return({ channel: { ttl: 15 } })
      allow(Html2rss::Web::FeedRuntime).to receive(:read).and_yield
      allow(Html2rss::Web::Feeds).to receive(:generate_feed).and_return('<rss/>')
    end

    def capture_runtime_reads
      reads = []

      allow(Html2rss::Web::FeedRuntime).to receive(:read) do |key:, ttl_seconds:, async_refresh:, &block|
        reads << { key:, ttl_seconds:, async_refresh: }
        block.call
      end

      reads
    end

    def exercise_both_formats(feed_name:, params:)
      described_class.call(feed_name:, params:, format: Html2rss::Web::FeedResponseFormat::RSS)
      described_class.call(feed_name:, params:, format: Html2rss::Web::FeedResponseFormat::JSON_FEED)
    end

    it 'uses the same cache key for rss and json representations', :aggregate_failures do
      reads = capture_runtime_reads

      exercise_both_formats(feed_name:, params:)

      expect(reads.map { |read| read[:key] }.uniq).to contain_exactly(reads.first[:key])
      expect(reads.map { |read| read[:ttl_seconds] }).to all(eq(900))
      expect(reads.map { |read| read[:async_refresh] }).to all(be(false))
    end

    it 'keeps ttl identical across representations', :aggregate_failures do
      reads = capture_runtime_reads

      exercise_both_formats(feed_name:, params:)

      expect(reads.map { |read| read[:ttl_seconds] }.uniq).to eq([900])
    end
  end
end
