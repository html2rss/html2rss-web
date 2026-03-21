# frozen_string_literal: true

require 'spec_helper'
require 'rack'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Responder do
  let(:response) { Rack::Response.new }
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
  let(:static_config) do
    {
      channel: { url: 'https://example.com', ttl: 10 },
      strategy: :faraday
    }
  end

  before do
    allow(Html2rss::Web::LocalConfig).to receive(:find).with('example').and_return(static_config)
    allow(Html2rss::Web::Observability).to receive(:emit)
  end

  context 'with a cacheable success result' do
    subject(:write_response) do
      described_class.call(
        request: request_for(path: '/example', accept: 'application/xml'),
        target_kind: :static,
        identifier: 'example'
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).with(result).and_return('<rss/>')
    end

    it 'writes the expected response tuple' do
      expect(response_tuple(write_response)).to eq([200, 'application/xml', '<rss/>'])
    end

    it 'resolves the source through the real request and source resolver path', :aggregate_failures do
      write_response

      expect(Html2rss::Web::Feeds::Service).to have_received(:call).with(
        have_attributes(
          source_kind: :static,
          cache_identity: a_string_starting_with('static:example:'),
          generator_input: include(strategy: :faraday, channel: { url: 'https://example.com', ttl: 10 }),
          ttl_seconds: 600
        )
      )
      expect(response['Cache-Control']).to include('max-age=600')
      expect(response['Cache-Control']).to include('public')
      expect(response['Vary']).to eq('Accept')
    end

    it 'emits success after writing the response' do
      write_response

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'feed.render',
        outcome: 'success',
        details: include(strategy: :faraday, url: 'https://example.com', feed_name: 'example'),
        level: :info
      )
    end
  end

  context 'with an error result' do
    subject(:write_response) do
      described_class.call(
        request: request_for(path: '/example.json', accept: 'application/feed+json'),
        target_kind: :static,
        identifier: 'example.json'
      )
    end

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
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
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
        request: request_for(path: '/example', accept: 'application/xml'),
        target_kind: :static,
        identifier: 'example'
      )
    end

    before do
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
      allow(Html2rss::Web::Feeds::RssRenderer).to receive(:call).and_raise(StandardError, 'render failed')
    end

    it 'emits only the failure event' do
      expect { write_response }.to raise_error(StandardError, 'render failed')

      expect(Html2rss::Web::Observability).to have_received(:emit).once.with(
        event_name: 'feed.render',
        outcome: 'failure',
        details: include(error_class: 'StandardError', error_message: 'render failed', feed_name: 'example'),
        level: :warn
      )
    end
  end

  private

  # @param path [String]
  # @param accept [String]
  # @return [Rack::Request]
  def request_for(path:, accept:)
    rack_response = response

    Rack::Request.new(
      Rack::MockRequest.env_for(path, 'HTTP_ACCEPT' => accept)
    ).tap do |request|
      request.define_singleton_method(:response) { rack_response }
    end
  end

  # @param body [String]
  # @return [Array<(Integer, String, String)>]
  def response_tuple(body)
    [response.status, response['Content-Type'], body]
  end
end
