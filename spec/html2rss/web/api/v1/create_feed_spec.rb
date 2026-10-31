# frozen_string_literal: true

require 'spec_helper'
require 'rack/mock'

# rubocop:disable-next RSpec/MultipleMemoizedHelpers, RSpec/MultipleExpectations, Layout/LineLength
RSpec.describe Html2rss::Web::Api::V1::CreateFeed do
  let(:account) { { username: 'alice', token: 'tok', allowed_urls: ['*'] } }
  let(:payload) { instance_double(Html2rss::Web::Feeds::Contracts::RenderPayload, site_title: 'Site Title') }
  let(:result) { instance_double(Html2rss::Web::Feeds::Contracts::RenderResult, status: :ok, payload:) }
  let(:body) { { url: 'https://example.com/news' } }
  let(:content_type) { 'application/json' }
  let(:env_overrides) { {} }
  let(:request) do
    json = body.is_a?(String) ? body : body.to_json
    env = Rack::MockRequest.env_for('/api/v1/feeds', method: 'POST', input: json, 'CONTENT_TYPE' => content_type,
                                                     **env_overrides)
    Rack::Request.new(env).tap { |r| r.define_singleton_method(:response) { @response ||= Rack::Response.new } }
  end

  before do
    allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(true)
    allow(Html2rss::Web::Auth).to receive_messages(authenticate: account, generate_feed_token: 'feed-token')
    allow(Html2rss::Web::Feeds::SourceResolver).to receive(:call).and_return(:resolved)
    allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(result)
    allow(Html2rss::Web::Observability).to receive(:emit)
  end

  describe '.call' do
    it 'authenticates the incoming request' do
      described_class.call(request)

      expect(Html2rss::Web::Auth).to have_received(:authenticate).with(request)
    end

    it 'returns the created feed payload with a 201 status', :aggregate_failures do
      response = described_class.call(request)

      expect(request.response.status).to eq(201)
      expect(response[:meta]).to eq(created: true)
      expect(response[:data][:feed]).to include(name: 'Site Title', url: 'https://example.com/news',
                                                feed_token: 'feed-token')
      expect(response[:data][:feed].keys).to match_array(described_class::FEED_ATTRIBUTE_KEYS)
    end

    it 'stamps created_at and updated_at identically as ISO 8601', :aggregate_failures do
      feed = described_class.call(request)[:data][:feed]

      expect(feed[:created_at]).to eq(feed[:updated_at])
      expect { Time.iso8601(feed[:created_at]) }.not_to raise_error
    end

    it 'emits a success event', :aggregate_failures do
      described_class.call(request)

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'feed.create', outcome: 'success', details: { url: 'https://example.com/news' }, level: :info
      )
    end

    it 'emits a failure event and re-raises', :aggregate_failures do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil)

      expect do
        described_class.call(request)
      end.to raise_error(Html2rss::Web::UnauthorizedError, 'Authentication required')
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        hash_including(event_name: 'feed.create', outcome: 'failure', level: :warn,
                       details: hash_including(error_code: 'UNAUTHORIZED', error_class: 'Html2rss::Web::UnauthorizedError',
                                               error_message: 'Authentication required'))
      )
    end

    it 'includes the url in failure details once params are built', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(false)

      expect { described_class.call(request) }.to raise_error(Html2rss::Web::AutoSourceDisabledError)
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        hash_including(outcome: 'failure', details: hash_including(url: 'https://example.com/news'))
      )
    end

    it 'omits the url from failure details when params were never built' do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil)
      expect { described_class.call(request) }.to raise_error(Html2rss::Web::UnauthorizedError)

      expect(Html2rss::Web::Observability).to have_received(:emit)
        .with(hash_including(outcome: 'failure', details: satisfy { |d| !d.key?(:url) }))
    end

    it 'fails when the feed token cannot be minted' do
      allow(Html2rss::Web::Auth).to receive(:generate_feed_token).and_return(nil)

      expect do
        described_class.call(request)
      end.to raise_error(Html2rss::Web::InternalServerError, 'Failed to create feed')
    end

    it 'mints the token for the account username and validated url, then resolves it', :aggregate_failures do
      described_class.call(request)

      expect(Html2rss::Web::Auth).to have_received(:generate_feed_token).with('alice', 'https://example.com/news')
      expect(Html2rss::Web::Feeds::SourceResolver).to have_received(:call).with(
        have_attributes(target_kind: :token, feed_name: nil, token: 'feed-token', params: {})
      )
      expect(Html2rss::Web::Feeds::Service).to have_received(:call).with(:resolved)
    end

    it 'raises a decided error when extraction is not ok' do
      decision = Html2rss::Web::ErrorClassifier.classify(Html2rss::Web::BadRequestError.new('x'))
      diagnostics = Html2rss::Web::ErrorClassifier::Diagnostics.new(
        strategy_attempts: [], request_id: 'rid', strategy_used: nil, render_ms: nil, error_category: nil,
        timeout_phase: nil, surface_category: nil
      )
      failed = instance_double(Html2rss::Web::Feeds::Contracts::RenderResult, status: :error, decision:, diagnostics:)
      allow(Html2rss::Web::Feeds::Service).to receive(:call).and_return(failed)

      expect { described_class.call(request) }
        .to raise_error(Html2rss::Web::ErrorClassifier::DecidedError) { |e| expect(e.diagnostics).to eq(diagnostics) }
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        hash_including(outcome: 'failure', details: hash_including(request_id: 'rid'))
      )
    end
  end

  describe 'feed name resolution' do
    it 'prefers the requested name (trimmed)' do
      payload_body = { url: 'https://example.com/news', name: '  My Feed ' }
      req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: payload_body.to_json,
                                                             'CONTENT_TYPE' => 'application/json'))
      req.define_singleton_method(:response) { @response ||= Rack::Response.new }

      expect(described_class.call(req)[:data][:feed][:name]).to eq('My Feed')
    end

    it 'treats a blank name as absent and uses the site title' do
      payload_body = { url: 'https://example.com/news', name: '   ' }
      req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: payload_body.to_json,
                                                             'CONTENT_TYPE' => 'application/json'))
      req.define_singleton_method(:response) { @response ||= Rack::Response.new }

      expect(described_class.call(req)[:data][:feed][:name]).to eq('Site Title')
    end

    it 'falls back to the channel title, then the url', :aggregate_failures do
      allow(payload).to receive(:site_title).and_return('')
      allow(Html2rss::Web::Feeds::ChannelTitle).to receive(:for).and_return('Channel')
      expect(described_class.call(request)[:data][:feed][:name]).to eq('Channel')

      allow(Html2rss::Web::Feeds::ChannelTitle).to receive(:for).and_return(nil)
      expect(described_class.call(request)[:data][:feed][:name]).to eq('https://example.com/news')
    end

    it 'looks up the channel title for the validated url' do
      allow(payload).to receive(:site_title).and_return(nil)
      allow(Html2rss::Web::Feeds::ChannelTitle).to receive(:for).and_return(nil)
      described_class.call(request)

      expect(Html2rss::Web::Feeds::ChannelTitle).to have_received(:for).with('https://example.com/news')
    end

    it 'handles results without a payload' do
      allow(result).to receive(:payload).and_return(nil)
      allow(Html2rss::Web::Feeds::ChannelTitle).to receive(:for).and_return('Channel')

      expect(described_class.call(request)[:data][:feed][:name]).to eq('Channel')
    end
  end

  describe 'input validation' do
    def error_for(body_hash, **)
      req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: body_hash.is_a?(String) ? body_hash : body_hash.to_json,
                                                             'CONTENT_TYPE' => 'application/json', **))
      req.define_singleton_method(:response) { @response ||= Rack::Response.new }
      described_class.call(req)
    end

    def feed_url_for(raw)
      error_for({ url: raw })[:data][:feed][:url]
    end

    it 'requires a url', :aggregate_failures do
      expect { error_for({}) }.to raise_error(Html2rss::Web::BadRequestError, 'URL parameter is required')
      expect { error_for({ url: '   ' }) }.to raise_error(Html2rss::Web::BadRequestError, 'URL parameter is required')
      expect { error_for({ url: nil }) }.to raise_error(Html2rss::Web::BadRequestError, 'URL parameter is required')
    end

    it 'rejects malformed urls' do
      expect do
        error_for({ url: 'ftp://example.com' })
      end.to raise_error(Html2rss::Web::BadRequestError, 'Invalid URL format')
    end

    it 'rejects urls outside the account allow-list' do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(account.merge(allowed_urls: ['https://other.com/*']))

      expect { error_for({ url: 'https://example.com/x' }) }
        .to raise_error(Html2rss::Web::ForbiddenError, 'URL not allowed for this account')
    end

    it 'normalizes bare hostnames, protocol-relative urls and trims whitespace', :aggregate_failures do
      expect(feed_url_for('example.com/news')).to eq('https://example.com/news')
      expect(feed_url_for('//example.com/news')).to eq('https://example.com/news')
      expect(feed_url_for('  https://example.com/news  ')).to eq('https://example.com/news')
      expect(feed_url_for('localhost:3000/x')).to eq('https://localhost:3000/x')
      expect(feed_url_for('127.0.0.1:8080')).to eq('https://127.0.0.1:8080/')
      expect(feed_url_for('EXAMPLE.COM?q=1')).to eq('https://example.com/?q=1')
    end

    it 'trims trailing whitespace before hostname detection' do
      expect(feed_url_for("example.com/news \n")).to eq('https://example.com/news')
    end

    it 'reads form params when no content type is sent' do
      req = Rack::Request.new(Rack::MockRequest.env_for('/?url=https%3A%2F%2Fq.example.com%2F', method: 'POST'))
      req.define_singleton_method(:response) { @response ||= Rack::Response.new }

      expect(described_class.call(req)[:data][:feed][:url]).to eq('https://q.example.com/')
    end

    it 'does not treat non-hostnames as urls', :aggregate_failures do
      expect { error_for({ url: 'not a host' }) }.to raise_error(Html2rss::Web::BadRequestError, 'Invalid URL format')
      expect { error_for({ url: 'example' }) }.to raise_error(Html2rss::Web::BadRequestError, 'Invalid URL format')
    end

    it 'rejects invalid or non-object JSON bodies', :aggregate_failures do
      expect { error_for('{nope') }.to raise_error(Html2rss::Web::BadRequestError, 'Invalid JSON payload')
      expect { error_for('[1]') }.to raise_error(Html2rss::Web::BadRequestError, 'Invalid JSON payload')
    end

    it 'treats an empty JSON body as missing url' do
      expect { error_for('  ') }.to raise_error(Html2rss::Web::BadRequestError, 'URL parameter is required')
    end

    it 'merges query params under the JSON body', :aggregate_failures do
      req = Rack::Request.new(Rack::MockRequest.env_for('/?url=https://query.example.com/&name=Q', method: 'POST',
                                                                                                   input: { name: 'Body' }.to_json,
                                                                                                   'CONTENT_TYPE' => 'application/json'))
      req.define_singleton_method(:response) { @response ||= Rack::Response.new }
      feed = described_class.call(req)[:data][:feed]

      expect(feed[:url]).to eq('https://query.example.com/')
      expect(feed[:name]).to eq('Body')
    end

    it 'reads form params for non-JSON requests' do
      req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: 'url=https%3A%2F%2Fform.example.com%2F',
                                                             'CONTENT_TYPE' => 'application/x-www-form-urlencoded'))
      req.define_singleton_method(:response) { @response ||= Rack::Response.new }

      expect(described_class.call(req)[:data][:feed][:url]).to eq('https://form.example.com/')
    end

    describe 'body limit' do
      let(:limit) { described_class::MAX_BODY_BYTES }

      def body_of(size)
        prefix = '{"url":"https://example.com/","pad":"'
        suffix = '"}'
        prefix + ('a' * (size - prefix.bytesize - suffix.bytesize)) + suffix
      end

      it 'accepts a body of exactly MAX_BODY_BYTES' do
        expect { error_for(body_of(limit)) }.not_to raise_error
      end

      it 'rejects a body one byte over, by content length', :aggregate_failures do
        expect { error_for(body_of(limit + 1)) }.to raise_error(Html2rss::Web::BadRequestError, 'Payload too large')
      end

      it 'rejects an oversized body even when content length is understated' do
        req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: body_of(limit + 1),
                                                               'CONTENT_TYPE' => 'application/json', 'CONTENT_LENGTH' => '10'))
        req.define_singleton_method(:response) { @response ||= Rack::Response.new }

        expect { described_class.call(req) }.to raise_error(Html2rss::Web::BadRequestError, 'Payload too large')
      end

      it 'rejects oversized form submissions by declared content length' do
        req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: 'url=x',
                                                               'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
                                                               'CONTENT_LENGTH' => (limit + 1).to_s))

        expect { described_class.call(req) }.to raise_error(Html2rss::Web::BadRequestError, 'Payload too large')
      end

      it 'accepts form submissions at exactly the limit by declared content length' do
        req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: 'url=https%3A%2F%2Fa.example.com%2F',
                                                               'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
                                                               'CONTENT_LENGTH' => limit.to_s))
        req.define_singleton_method(:response) { @response ||= Rack::Response.new }

        expect { described_class.call(req) }.not_to raise_error
      end

      it 'rewinds the body after reading' do
        req = Rack::Request.new(Rack::MockRequest.env_for('/', method: 'POST', input: { url: 'https://example.com/' }.to_json,
                                                               'CONTENT_TYPE' => 'application/json'))
        req.define_singleton_method(:response) { @response ||= Rack::Response.new }
        described_class.call(req)

        expect(req.body.read).to include('example.com')
      end
    end
  end
end
