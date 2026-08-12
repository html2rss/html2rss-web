# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::Request do
  let(:request) { instance_double(Rack::Request, params: { 'page' => '2' }) }

  def request_tuple(parsed)
    [parsed.target_kind, parsed.feed_name, parsed.token, parsed.params]
  end

  it 'builds a static request with normalized feed name', :aggregate_failures do
    parsed = described_class.call(request:, target_kind: :static, identifier: 'legacy.json')

    expect(request_tuple(parsed)).to eq(
      [:static, 'legacy', nil, { 'page' => '2' }]
    )
  end

  it 'builds a token request with normalized token', :aggregate_failures do
    parsed = described_class.call(request:, target_kind: :token, identifier: 'token.json')

    expect(request_tuple(parsed)).to eq(
      [:token, nil, 'token', { 'page' => '2' }]
    )
  end
end
