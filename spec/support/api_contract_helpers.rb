# frozen_string_literal: true

require 'json'

module ApiContractHelpers
  OPTIONAL_ERROR_FIELDS = {
    kind: 'kind',
    retryable: 'retryable',
    next_action: 'next_action',
    retry_action: 'retry_action'
  }.freeze

  def response_json(response)
    JSON.parse(response.body)
  end

  def expect_success_response(response)
    json = response_json(response)
    expect(json['success']).to be(true)
    yield json if block_given?
    json
  end

  def expect_error_response(response, code:, **expected)
    json = response_json(response)
    error = json.fetch('error')
    expect(json['success']).to be(false)
    expect(error.fetch('code')).to eq(code)
    expect_optional_error_fields(error, expected)
    yield json if block_given?
    json
  end

  def expect_feed_payload(json)
    feed = json.fetch('data').fetch('feed')
    expect(feed.keys).to contain_exactly(
      'id', 'name', 'url', 'feed_token', 'public_url', 'json_public_url', 'created_at', 'updated_at'
    )
    expect_feed_identifier_payload(feed)
    expect_feed_source_payload(feed)
    feed
  end

  def expect_feed_identifier_payload(feed)
    expect(feed.fetch('feed_token')).to be_a(String)
    expect(feed.fetch('public_url')).to match(%r{^/api/v1/feeds/})
    expect(feed.fetch('json_public_url')).to match(%r{^/api/v1/feeds/.+\.json$})
  end

  def expect_feed_source_payload(feed)
    expect(feed.fetch('url')).to be_a(String)
    expect(feed.fetch('name')).to be_a(String)
  end

  private

  def expect_optional_error_fields(error, expected)
    OPTIONAL_ERROR_FIELDS.each do |key, field_name|
      next unless expected.key?(key)

      expect(error.fetch(field_name)).to eq(expected[key])
    end
  end
end

RSpec.configure do |config|
  config.include ApiContractHelpers
end
