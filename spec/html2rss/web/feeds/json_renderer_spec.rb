# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::JsonRenderer do
  subject(:render_empty_feed) { described_class.call(empty_result) }

  let(:payload) do
    Html2rss::Web::Feeds::Contracts::RenderPayload.new(
      feed: Object.new,
      site_title: 'https://example.com/articles',
      url: 'https://example.com/articles',
      strategy: 'faraday'
    )
  end
  let(:empty_result) do
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :empty,
      payload: payload,
      message: nil,
      ttl_seconds: 600,
      cache_key: 'feed_result:test',
      error_message: nil
    )
  end

  it 'passes the normalized site title into empty-feed rendering' do
    allow(Html2rss::Web::JsonFeedBuilder).to receive(:build_empty_feed_warning).and_return('{"items":[]}')

    render_empty_feed

    expect(Html2rss::Web::JsonFeedBuilder).to have_received(:build_empty_feed_warning).with(expected_builder_args)
  end

  # @return [Hash{Symbol=>String}]
  def expected_builder_args
    {
      url: 'https://example.com/articles',
      strategy: 'faraday',
      site_title: 'https://example.com/articles'
    }
  end
end
