# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Service do
  subject(:result) { described_class.call(resolved_source) }

  let(:resolved_source) do
    Html2rss::Web::Feeds::Contracts::ResolvedSource.new(
      source_kind: :static,
      cache_identity: 'example-feed:abc123',
      generator_input: {
        channel: { url: 'https://example.com/articles' },
        auto_source: {}
      },
      ttl_seconds: 900,
      url: 'https://example.com/articles',
      strategy: nil,
      feed_name: 'example.com/articles',
      directory_defaults: {},
      request_params: {}
    )
  end

  before do
    Html2rss::Web::Feeds::Cache.clear!
    Html2rss::Web::Feeds::LastResults.clear!
    allow(Html2rss::Web::Feeds::ChannelTitle).to receive(:for)
      .with('https://example.com/articles')
      .and_return('Example Feed')
  end

  context 'when feed generation succeeds with items' do
    let(:feed_result) { instance_double(Html2rss::FeedResult, empty?: false, channel_title: nil) }

    before do
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input).and_return(feed_result)
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

    it 'retains the normalized payload object' do
      expect(result.payload).to eq(expected_payload)
    end

    it 'prefers FeedResult#channel_title over metadata for site_title' do
      allow(feed_result).to receive(:channel_title).and_return('Channel From Scrape')

      expect(result.payload.site_title).to eq('Channel From Scrape')
    end

    it 'records last_result for directory-defaults static scrapes', :aggregate_failures do
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input).and_return(feed_result)

      described_class.call(resolved_source)

      expect(Html2rss::Web::Feeds::LastResults['example.com/articles'].state).to eq(:ok)
    end

    it 'does not refresh last_result on cache hits' do
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input).and_return(feed_result)
      described_class.call(resolved_source)
      first_at = Html2rss::Web::Feeds::LastResults['example.com/articles'].at

      travel = first_at + 60
      allow(Time).to receive(:now).and_return(travel)
      described_class.call(resolved_source)

      expect(Html2rss::Web::Feeds::LastResults['example.com/articles'].at).to eq(first_at)
    end

    it 'does not record when request params diverge from directory defaults' do
      custom = Html2rss::Web::Feeds::Contracts::ResolvedSource.new(
        **resolved_source.to_h,
        directory_defaults: { 'id' => 'default' },
        request_params: { 'id' => 'custom' }
      )
      allow(Html2rss).to receive(:feed_result).with(custom.generator_input).and_return(feed_result)

      described_class.call(custom)

      expect(Html2rss::Web::Feeds::LastResults['example.com/articles']).to eq(
        Html2rss::Web::Feeds::LastResult.unknown
      )
    end

    it 'reuses the cached result for repeated requests' do
      described_class.call(resolved_source)
      described_class.call(resolved_source)

      expect(Html2rss).to have_received(:feed_result).once
    end
  end

  context 'when the generated feed has no items' do
    let(:feed_result) { instance_double(Html2rss::FeedResult, empty?: true, channel_title: 'Page Title From Head') }

    before do
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input).and_return(feed_result)
    end

    it 'marks the result as empty' do
      expect(result.status).to eq(:empty)
    end

    it 'sets feed_empty as the empty reason' do
      expect(result.empty_reason).to eq('feed_empty')
    end

    it 'attaches the extraction-empty Decision' do
      expect(result.decision).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY)
    end

    it 'uses channel_title for empty scrape site_title' do
      expect(result.payload.site_title).to eq('Page Title From Head')
    end

    it 'falls back to the source url when channel_title and metadata are blank' do
      allow(feed_result).to receive(:channel_title).and_return('')
      allow(Html2rss::Web::Feeds::ChannelTitle).to receive(:for)
        .with('https://example.com/articles')
        .and_return(nil)

      expect(result.payload.site_title).to eq('https://example.com/articles')
    end
  end

  context 'when generation fails' do
    before do
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input).and_raise(StandardError, 'boom')
    end

    it 'marks the result as an error' do
      expect(result.status).to eq(:error)
    end

    it 'exposes the internal Decision message to clients' do
      expect(result.client_message).to eq('Internal Server Error')
    end

    it 'retains the internal error details for observability' do
      expect(result.error_message).to eq('boom')
    end

    it 'drops the feed payload' do
      expect(result.payload).to be_nil
    end

    it 'does not cache the failure result' do
      described_class.call(resolved_source)
      described_class.call(resolved_source)

      expect(Html2rss).to have_received(:feed_result).twice
    end
  end

  # @return [Html2rss::Web::Feeds::Contracts::RenderPayload]
  def expected_payload
    Html2rss::Web::Feeds::Contracts::RenderPayload.new(
      feed: feed_result,
      site_title: 'Example Feed',
      url: 'https://example.com/articles'
    )
  end

  context 'when auto fallback exhausts without feed items' do
    let(:no_feed_items_extracted_class) do
      stub_const('Html2rss::NoFeedItemsExtracted', Class.new(Html2rss::Error) do
        def initialize(attempts:)
          @attempts = attempts
          super('No feed items extracted after auto fallback')
        end

        attr_reader :attempts
      end)
    end

    before do
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input).and_raise(
        no_feed_items_extracted_class.new(
          attempts: [
            { strategy: :faraday, items_count: 0, error_class: nil },
            { strategy: :botasaurus, items_count: 0, error_class: nil }
          ]
        )
      )
    end

    it 'maps the result to empty extraction instead of a server failure', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
      expect(result.status).to eq(:empty)
      expect(result.empty_reason).to eq('content_extraction_empty')
      expect(result.decision).to eq(Html2rss::Web::ErrorClassifier::EXTRACTION_EMPTY)
      expect(result.error_message).to include('No feed items extracted after auto fallback')
      expect(result.diagnostics.strategy_attempts).to eq(
        [
          { strategy: :faraday, items_count: 0, error_class: nil },
          { strategy: :botasaurus, items_count: 0, error_class: nil }
        ]
      )
      expect(result.payload).to have_attributes(
        url: 'https://example.com/articles',
        site_title: 'Example Feed'
      )
    end

    it 'caches the empty result' do
      described_class.call(resolved_source)
      described_class.call(resolved_source)

      expect(Html2rss).to have_received(:feed_result).once
    end

    it 'maps NoFeedItemsExtracted nested in Exception#cause to empty extraction', :aggregate_failures do
      root = no_feed_items_extracted_class.new(
        attempts: [{ strategy: :faraday, items_count: 0, error_class: nil }]
      )
      wrapper = StandardError.new('strategy failed')
      allow(wrapper).to receive(:cause).and_return(root)
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input).and_raise(wrapper)

      expect(result.status).to eq(:empty)
      expect(result.empty_reason).to eq('content_extraction_empty')
      expect(result.diagnostics.strategy_attempts).to eq([{ strategy: :faraday, items_count: 0, error_class: nil }])
    end
  end

  context 'when a classified decision is not cacheable' do
    before do
      allow(Html2rss).to receive(:feed_result).with(resolved_source.generator_input)
                                              .and_raise(StandardError, 'classified boom')
      allow(Html2rss::Web::ErrorClassifier).to receive(:classify).and_return(
        Html2rss::Web::ErrorClassifier::Decision.new(
          status: 422,
          code: 'NON_CACHEABLE',
          message: 'classified but not cacheable',
          kind: 'input',
          cacheable: false,
          retryable: false,
          next_action: 'correct_input',
          retry_action: 'none'
        )
      )
    end

    it 'marks the result as an error instead of empty', :aggregate_failures do
      expect(result.status).to eq(:error)
      expect(result.decision.code).to eq('NON_CACHEABLE')
      expect(result.empty_reason).to be_nil
      expect(result.diagnostics).to eq(Html2rss::Web::ErrorClassifier::Diagnostics.empty)
    end
  end
end
