# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

require_relative '../../../app'

RSpec.describe Html2rss::Web::ErrorResponder do
  def build_request(path:, accept: nil, target: nil, rack_errors: StringIO.new)
    env = { 'rack.errors' => rack_errors, Html2rss::Web::RequestTarget::ENV_KEY => target }
    env['HTTP_ACCEPT'] = accept if accept

    instance_double(
      Rack::Request,
      path: path,
      path_info: path,
      env: env,
      get_header: env['HTTP_ACCEPT']
    )
  end

  def respond_with(error:, path:, accept: nil, target: nil, response: Rack::Response.new)
    request = build_request(path:, accept:, target:)
    body = described_class.respond(request:, response:, error:)

    [response, body]
  end

  def api_error_response
    response, body = respond_with(
      error: StandardError.new('boom'),
      path: '/api/v1/feeds',
      target: Html2rss::Web::RequestTarget::API
    )

    [response.status, response['Content-Type'], JSON.parse(body)]
  end

  def legacy_error_response
    allow(Html2rss::Web::XmlBuilder).to receive(:build_error_feed).and_return('<error/>')
    response, body = respond_with(
      error: Html2rss::Web::InternalServerError.new('oops'),
      path: '/legacy'
    )

    [response.status, response['Content-Type'], body]
  end

  def json_feed_error_response
    response, body = respond_with(
      error: Html2rss::Web::UnauthorizedError.new('Invalid token'),
      path: '/api/v1/feeds/token.json',
      target: Html2rss::Web::RequestTarget::FEED
    )

    [response.status, response['Content-Type'], JSON.parse(body).slice('version', 'title', 'description')]
  end

  def xml_preferred_feed_error_response
    response, body = respond_with(
      error: Html2rss::Web::UnauthorizedError.new('Invalid token'),
      path: '/api/v1/feeds/token',
      accept: 'application/xml;q=1.0, application/feed+json;q=0.2',
      target: Html2rss::Web::RequestTarget::FEED
    )

    [response['Content-Type'], body.include?('Invalid token')]
  end

  def expected_api_error_response
    [500, 'application/json',
     {
       'success' => false,
       'error' => {
         'code' => Html2rss::Web::Api::V1::Contract::CODES[:internal_server_error],
         'message' => 'Internal Server Error'
       }
     }]
  end

  describe '.respond' do
    it 'returns json error payload for unexpected api errors' do
      expect(api_error_response).to eq(expected_api_error_response)
    end

    it 'returns xml error payload for non-api routes' do
      expect(legacy_error_response).to eq([500, 'application/xml', '<error/>'])
    end

    it 'returns a JSON Feed-shaped error payload for json feed routes' do
      expect(json_feed_error_response).to eq(
        [401, 'application/feed+json',
         { 'version' => 'https://jsonfeed.org/version/1.1', 'title' => 'Error',
           'description' => 'Failed to generate feed: Invalid token' }]
      )
    end

    it 'keeps the xml error representation when xml outranks json' do
      expect(xml_preferred_feed_error_response).to eq(['application/xml', true])
    end
  end
end
