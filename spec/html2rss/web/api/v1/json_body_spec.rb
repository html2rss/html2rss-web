# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Html2rss::Web::Api::V1::JsonBody do
  def request_for(body, content_length: body.bytesize)
    env = Rack::MockRequest.env_for(
      '/api/v1/feeds',
      method: 'POST',
      input: body,
      'CONTENT_TYPE' => 'application/json',
      'CONTENT_LENGTH' => content_length.to_s
    )
    Rack::Request.new(env)
  end

  it 'parses a JSON object and rewinds the body', :aggregate_failures do
    request = request_for('{"url":"https://example.com"}')

    expect(described_class.object(request)).to eq('url' => 'https://example.com')
    expect(request.body.read).to eq('{"url":"https://example.com"}')
  end

  it 'treats an empty body as an empty object' do
    expect(described_class.object(request_for(''))).to eq({})
  end

  it 'rejects a JSON array' do
    expect { described_class.object(request_for('[1]')) }
      .to raise_error(Html2rss::Web::BadRequestError, 'Invalid JSON payload')
  end

  it 'rejects a declared length over the cap without reading', :aggregate_failures do
    body = StringIO.new('{"url":"https://example.com"}')
    request = request_for(body, content_length: described_class::MAX_BODY_BYTES + 1)

    expect { described_class.object(request) }
      .to raise_error(Html2rss::Web::BadRequestError, 'Payload too large')
    expect(body.pos).to eq(0)
  end

  it 'rejects a body longer than the cap when length is understated' do
    raw = 'x' * (described_class::MAX_BODY_BYTES + 1)

    expect { described_class.object(request_for(raw, content_length: 1)) }
      .to raise_error(Html2rss::Web::BadRequestError, 'Payload too large')
  end
end
