# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'

RSpec.describe Html2rss::Web::RequestContextMiddleware do
  it 'classifies the closed route groups', :aggregate_failures do
    app = middleware_app
    request = Rack::MockRequest.new(app)

    expect(request.get('/api/v1/health').body).to eq('health:GET')
    expect(request.get('/api/v1/health/ready').body).to eq('health:GET')
    expect(request.get('/api/v1/configs').body).to eq('catalog:GET')
    expect(request.post('/api/v1/feeds').body).to eq('feed_create:POST')
    expect(request.get('/api/v1/feeds/sensitive-token-value.json').body).to eq('feed_render:GET')
    expect(request.get('/feeds/example').body).to eq('static:GET')
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
