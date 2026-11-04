# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::JsonBody do
  let(:limit) { described_class::MAX_BYTES }

  describe '.object' do
    it 'parses a JSON object and rewinds the body', :aggregate_failures do
      request = refine_request({ a: 1 })

      expect(described_class.object(request)).to eq('a' => 1)
      expect(request.body.read).to eq('{"a":1}')
    end

    it 'treats empty and blank bodies as an empty object', :aggregate_failures do
      expect(described_class.object(refine_request(''))).to eq({})
      expect(described_class.object(refine_request('  '))).to eq({})
    end

    it 'rejects a declared length over the limit before reading' do
      request = refine_request('{}', 'CONTENT_LENGTH' => (limit + 1).to_s)

      expect { described_class.object(request) }.to raise_error(Html2rss::Web::BadRequestError, 'Payload too large')
    end

    it 'accepts a body of exactly MAX_BYTES' do
      raw = %({"a":"#{'x' * (limit - 8)}"})

      expect(described_class.object(refine_request(raw)).keys).to eq(['a'])
    end

    it 'rejects a body over MAX_BYTES even when content-length is absent' do
      raw = %({"a":"#{'x' * (limit - 7)}"})
      request = refine_request(raw)
      request.env.delete('CONTENT_LENGTH')

      expect { described_class.object(request) }.to raise_error(Html2rss::Web::BadRequestError, 'Payload too large')
    end

    it 'parses when no content length was declared' do
      request = refine_request({ a: 1 })
      request.env.delete('CONTENT_LENGTH')

      expect(described_class.object(request)).to eq('a' => 1)
    end

    it 'never reads more than one byte past the limit' do
      request = refine_request({ a: 1 })
      allow(request.body).to receive(:read).and_call_original
      described_class.object(request)

      expect(request.body).to have_received(:read).with(limit + 1)
    end

    it 'rejects malformed JSON and non-objects', :aggregate_failures do
      ['{nope', '[1]', '"x"'].each do |raw|
        expect { described_class.object(refine_request(raw)) }
          .to raise_error(Html2rss::Web::BadRequestError, 'Invalid JSON payload')
      end
    end
  end

  describe '.enforce_limit!' do
    it 'rejects a declared length over the limit without reading', :aggregate_failures do
      request = refine_request('{}', 'CONTENT_LENGTH' => (limit + 1).to_s)
      allow(request.body).to receive(:read)

      expect { described_class.enforce_limit!(request) }.to raise_error(Html2rss::Web::BadRequestError)
      expect(request.body).not_to have_received(:read)
    end

    it 'allows a request without a declared length' do
      request = refine_request('{}')
      request.env.delete('CONTENT_LENGTH')

      expect { described_class.enforce_limit!(request) }.not_to raise_error
    end

    it 'allows exactly the limit' do
      expect { described_class.enforce_limit!(refine_request('{}', 'CONTENT_LENGTH' => limit.to_s)) }
        .not_to raise_error
    end
  end
end
