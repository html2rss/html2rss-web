# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'

RSpec.describe Html2rss::Web::RequestContextMiddleware do
  it 'classifies the closed route groups', :aggregate_failures do
    app = middleware_app
    request = Rack::MockRequest.new(app)

    route_group_rows.each do |http_method, path, group|
      response = request.request(http_method, path)
      expect(response.body).to eq("#{group}:#{http_method}"), "expected #{http_method} #{path}"
    end
  end

  it 'sets response request id header' do
    response = Rack::MockRequest.new(middleware_app).get('/api/v1/health')
    expect(response['X-Request-Id']).not_to be_empty
  end

  it 'redacts feed tokens from request context paths' do
    response = Rack::MockRequest.new(redaction_app).get('/api/v1/feeds/sensitive-token-value.json')
    expect(response.body).to eq('/api/v1/feeds/[REDACTED].json')
  end

  private

  # @return [Array<Array<(String, String, String)>>]
  def route_group_rows # rubocop:disable Metrics/MethodLength
    [
      ['GET', '/api/v1/health', 'health'],
      ['GET', '/api/v1/health/ready', 'health'],
      ['GET', '/api/v1/configs', 'catalog'],
      ['POST', '/api/v1/feeds', 'feed_create'],
      ['GET', '/api/v1/feeds/sensitive-token-value.json', 'feed_render'],
      ['GET', '/apple.com/newsroom.rss', 'feed_render'],
      ['GET', '/feeds/example', 'feed_render'],
      ['GET', '/', 'static'],
      ['GET', '/assets/app.js', 'static'],
      ['GET', '/api/v1/nope', 'static']
    ]
  end

  # @return [Html2rss::Web::RequestContextMiddleware]
  def middleware_app
    app = lambda do |_env|
      context = Html2rss::Web::RequestContext.current
      [200, { 'Content-Type' => 'text/plain' }, ["#{context.route_group}:#{context.http_method}"]]
    end
    described_class.new(app)
  end

  # @return [Html2rss::Web::RequestContextMiddleware]
  def redaction_app
    app = lambda do |_env|
      context = Html2rss::Web::RequestContext.current
      [200, { 'Content-Type' => 'text/plain' }, [context.path]]
    end
    described_class.new(app)
  end
end
