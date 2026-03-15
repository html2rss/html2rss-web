# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Responder do
  let(:response) { Rack::Response.new }
  let(:request) { instance_double(Struct.new(:response), response: response) }

  def feed_request(representation)
    Html2rss::Web::Feeds::Contracts::Request.new(
      target_kind: :token,
      representation: representation,
      feed_name: nil,
      token: 'token',
      params: {}
    )
  end

  def resolved_source
    Html2rss::Web::Feeds::Contracts::ResolvedSource.new(
      source_kind: :token,
      cache_identity: 'token:abc',
      generator_input: { strategy: :ssrf_filter, channel: { url: 'https://example.com' } },
      ttl_seconds: 600
    )
  end

  context 'with a cacheable success result' do
    subject(:write_response) do
      described_class.call(
        request: request,
        target_kind: :token,
        identifier: 'token'
      )
    end

    let(:representation) { Html2rss::Web::FeedResponseFormat::RSS }

    let(:result) do
      Html2rss::Web::Feeds::Contracts::RenderResult.new(
        status: :ok,
        payload: nil,
        message: nil,
        ttl_seconds: 600,
        cache_key: 'feed_result:test',
        error_message: nil
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Request).to receive(:call).and_return(feed_request(representation))
      allow(Html2rss::Web::Feeds::SourceResolver).to receive(:call).and_return(resolved_source)
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
      allow(Html2rss::Web::Observability).to receive(:emit)
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).with(result).and_return('<rss/>')
    end

    it 'writes the expected response tuple' do
      expect(response_tuple(write_response)).to eq([200, 'application/xml', '<rss/>'])
    end

    it 'marks the response as cacheable', :aggregate_failures do
      write_response

      expect(response['Cache-Control']).to include('max-age=600')
      expect(response['Cache-Control']).to include('public')
      expect(response['Vary']).to eq('Accept')
    end

    it 'emits success after writing the response' do
      write_response

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'feed.render',
        outcome: 'success',
        details: include(strategy: :ssrf_filter, url: 'https://example.com'),
        level: :info
      )
    end
  end

  context 'with an error result' do
    subject(:write_response) do
      described_class.call(
        request: request,
        target_kind: :token,
        identifier: 'token'
      )
    end

    let(:representation) { Html2rss::Web::FeedResponseFormat::JSON_FEED }

    let(:result) do
      Html2rss::Web::Feeds::Contracts::RenderResult.new(
        status: :error,
        payload: nil,
        message: 'Internal Server Error',
        ttl_seconds: 600,
        cache_key: 'feed_result:error',
        error_message: 'timeout'
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Request).to receive(:call).and_return(feed_request(representation))
      allow(Html2rss::Web::Feeds::SourceResolver).to receive(:call).and_return(resolved_source)
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
      allow(Html2rss::Web::Observability).to receive(:emit)
      allow(Html2rss::Web::Feeds::JsonRenderer).to receive(:call).with(result).and_return('{"title":"Error"}')
    end

    it 'writes the expected response tuple' do
      expect(response_tuple(write_response)).to eq([500, 'application/feed+json', '{"title":"Error"}'])
    end

    it 'marks the response as non-cacheable', :aggregate_failures do
      write_response

      expect(response['Cache-Control']).to include('no-store')
      expect(response['Vary']).to eq('Accept')
    end
  end

  context 'when response rendering fails after feed generation succeeds' do
    subject(:write_response) do
      described_class.call(
        request: request,
        target_kind: :token,
        identifier: 'token'
      )
    end

    let(:representation) { Html2rss::Web::FeedResponseFormat::RSS }

    let(:result) do
      Html2rss::Web::Feeds::Contracts::RenderResult.new(
        status: :ok,
        payload: nil,
        message: nil,
        ttl_seconds: 600,
        cache_key: 'feed_result:test',
        error_message: nil
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Request).to receive(:call).and_return(feed_request(representation))
      allow(Html2rss::Web::Feeds::SourceResolver).to receive(:call).and_return(resolved_source)
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
      allow(Html2rss::Web::Observability).to receive(:emit)
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).and_raise(StandardError, 'render failed')
    end

    it 'emits only the failure event' do
      expect { write_response }.to raise_error(StandardError, 'render failed')

      expect(Html2rss::Web::Observability).to have_received(:emit).once.with(
        event_name: 'feed.render',
        outcome: 'failure',
        details: include(error_class: 'StandardError', error_message: 'render failed'),
        level: :warn
      )
    end
  end

  private

  # @param body [String]
  # @return [Array<(Integer, String, String)>]
  def response_tuple(body)
    [response.status, response['Content-Type'], body]
  end
end
