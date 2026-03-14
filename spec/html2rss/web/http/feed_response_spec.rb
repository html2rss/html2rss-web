# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Http::FeedResponse do
  let(:response) { Rack::Response.new }

  context 'with a cacheable success result' do
    subject(:write_response) do
      described_class.call(
        response: response,
        representation: Html2rss::Web::FeedResponseFormat::RSS,
        result: result
      )
    end

    let(:result) do
      Html2rss::Web::FeedContracts::RenderResult.new(
        status: :ok,
        payload: nil,
        message: nil,
        ttl_seconds: 600,
        cache_key: 'feed_result:test',
        error_message: nil
      )
    end

    before do
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).with(result).and_return('<rss/>')
    end

    it 'writes the expected response tuple' do
      expect(response_tuple(write_response)).to eq([200, 'application/xml', '<rss/>'])
    end

    it 'marks the response as cacheable' do
      write_response

      expect(response['Cache-Control']).to include('public')
    end
  end

  context 'with an error result' do
    subject(:write_response) do
      described_class.call(
        response: response,
        representation: Html2rss::Web::FeedResponseFormat::JSON_FEED,
        result: result
      )
    end

    let(:result) do
      Html2rss::Web::FeedContracts::RenderResult.new(
        status: :error,
        payload: nil,
        message: 'Internal Server Error',
        ttl_seconds: 600,
        cache_key: 'feed_result:error',
        error_message: 'timeout'
      )
    end

    before do
      allow(Html2rss::Web::Feeds::JsonRenderer).to receive(:call).with(result).and_return('{"title":"Error"}')
    end

    it 'writes the expected response tuple' do
      expect(response_tuple(write_response)).to eq([500, 'application/feed+json', '{"title":"Error"}'])
    end

    it 'marks the response as non-cacheable' do
      write_response

      expect(response['Cache-Control']).to include('no-store')
    end
  end

  private

  # @param body [String]
  # @return [Array<(Integer, String, String)>]
  def response_tuple(body)
    [response.status, response['Content-Type'], body]
  end
end
