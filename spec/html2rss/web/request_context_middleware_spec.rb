# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'

require_relative '../../../app/web/request/request_context'
require_relative '../../../app/web/request/request_context_middleware'

RSpec.describe Html2rss::Web::RequestContextMiddleware do
  it 'sets route group in request context' do
    response = Rack::MockRequest.new(middleware_app).get('/api/v1/health')
    expect(response.body).to eq('api_v1:GET')
  end

  it 'sets response request id header' do
    response = Rack::MockRequest.new(middleware_app).get('/api/v1/health')
    expect(response['X-Request-Id']).not_to be_empty
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
end
