# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

RSpec.describe 'Dockerized API smoke test', :docker do # rubocop:disable RSpec/DescribeClass
  let(:base_url) { ENV.fetch('SMOKE_BASE_URL', 'http://127.0.0.1:3000') }
  let(:health_token) { ENV.fetch('SMOKE_HEALTH_TOKEN', 'health-check-token-xyz789') }
  let(:feed_token) { ENV.fetch('SMOKE_API_TOKEN', 'allow-any-urls-abcd-4321') }

  def get_json(path, headers: {})
    uri = URI.join(base_url, path)
    request = Net::HTTP::Get.new(uri, headers)
    perform_request(uri, request)
  end

  def post_json(path, body:, headers: {})
    uri = URI.join(base_url, path)
    request = Net::HTTP::Post.new(uri, headers.merge('Content-Type' => 'application/json'))
    request.body = JSON.generate(body)
    perform_request(uri, request)
  end

  def perform_request(uri, request)
    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
    [response, response.body.to_s.empty? ? {} : JSON.parse(response.body)]
  end

  it 'exposes health endpoints without authentication requirements', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    response, payload = get_json('/api/v1/health/ready')
    expect(response).to be_a(Net::HTTPOK)
    expect(payload.fetch('success')).to be(true)

    response, payload = get_json('/api/v1/health/live')
    expect(response).to be_a(Net::HTTPOK)
    expect(payload.fetch('success')).to be(true)
  end

  it 'requires authentication for the secure health endpoint', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    response, payload = get_json('/api/v1/health')
    expect(response).to be_a(Net::HTTPUnauthorized)
    expect(payload.dig('error', 'code')).to eq('UNAUTHORIZED')

    response, payload = get_json('/api/v1/health', headers: { 'Authorization' => "Bearer #{health_token}" })
    expect(response).to be_a(Net::HTTPOK)
    expect(payload.dig('data', 'health', 'status')).to eq('healthy')
  end

  it 'creates a feed when provided with valid credentials', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    payload = {
      url: 'https://example.com/articles',
      strategy: 'ssrf_filter'
    }

    response, body = post_json('/api/v1/feeds', body: payload)
    expect(response).to be_a(Net::HTTPUnauthorized)
    expect(body.dig('error', 'code')).to eq('UNAUTHORIZED')

    response, body = post_json('/api/v1/feeds',
                               body: payload,
                               headers: { 'Authorization' => "Bearer #{feed_token}" })

    expect(response.code).to eq('201')
    expect(body.fetch('success')).to be(true)
    expect(body.dig('data', 'feed', 'public_url')).to match(%r{^/api/v1/feeds/})
  end
end
