# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Cache do
  attr_writer :fetch_calls

  let(:result) do
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(
        feed: Object.new,
        site_title: 'Example',
        url: 'https://example.com',
        strategy: 'ssrf_filter'
      ),
      message: nil,
      ttl_seconds: 60,
      cache_key: 'feed_result:test',
      error_message: nil
    )
  end

  before do
    described_class.clear!
  end

  it 'returns the cached result on repeated reads for the same key' do
    expect(read_same_key_twice).to all(eq(result))
  end

  it 'rebuilds after the cache is cleared' do
    fetch_with_counter
    described_class.clear!(reason: 'spec')

    expect { fetch_with_counter }.to change { fetch_calls }.from(1).to(2)
  end

  private

  # @return [Array<Html2rss::Web::Feeds::Contracts::RenderResult>]
  def read_same_key_twice
    [fetch_with_counter, fetch_with_counter]
  end

  # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
  def fetch_with_counter
    described_class.fetch('feed_result:test', ttl_seconds: 60) do
      self.fetch_calls += 1
      result
    end
  end

  # @return [Integer]
  def fetch_calls
    @fetch_calls ||= 0
  end
end
