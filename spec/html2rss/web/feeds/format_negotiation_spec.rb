# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Feeds::FormatNegotiation do
  def rack_request(path:, accept: nil)
    env = Rack::MockRequest.env_for(path, 'HTTP_HOST' => 'example.test')
    env['HTTP_ACCEPT'] = accept if accept
    Rack::Request.new(env)
  end

  describe '.format_for_request' do
    it 'prefers path extension over Accept', :aggregate_failures do
      json_path = rack_request(path: '/feed.json', accept: 'application/xml')
      xml_path = rack_request(path: '/feed.xml', accept: 'application/feed+json')

      expect(described_class.format_for_request(json_path)).to eq(described_class::JSON_FEED)
      expect(described_class.format_for_request(xml_path)).to eq(described_class::RSS)
    end
  end

  describe '.format_for_request with whitespace before Accept parameters' do
    it 'ignores optional whitespace around the semicolon (RFC 7231)', :aggregate_failures do
      json = rack_request(path: '/feed', accept: 'application/json ; q=0.5')
      rss = rack_request(path: '/feed', accept: 'application/json;q=0.2 , application/xml ; q=0.9')

      expect(described_class.format_for_request(json)).to eq(described_class::JSON_FEED)
      expect(described_class.format_for_request(rss)).to eq(described_class::RSS)
    end
  end

  describe '.strip_known_extension' do
    it 'removes known extensions', :aggregate_failures do
      expect(described_class.strip_known_extension('/feed.json')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed.rss')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed')).to eq('/feed')
    end
  end

  describe '.format_for_request (Accept negotiation)' do
    def negotiate(accept, path: '/feed')
      described_class.format_for_request(rack_request(path:, accept:))
    end

    it 'defaults to RSS without an Accept header or path extension', :aggregate_failures do
      expect(negotiate(nil)).to eq(described_class::RSS)
      expect(negotiate('')).to eq(described_class::RSS)
      expect(negotiate('text/html')).to eq(described_class::RSS)
    end

    it 'chooses JSON Feed for JSON media types', :aggregate_failures do
      expect(negotiate('application/feed+json')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/json')).to eq(described_class::JSON_FEED)
      expect(negotiate('APPLICATION/JSON')).to eq(described_class::JSON_FEED)
      expect(negotiate(' application/json; q=0.5 ')).to eq(described_class::JSON_FEED)
    end

    it 'chooses RSS for RSS media types', :aggregate_failures do
      %w[application/rss+xml application/xml text/xml].each do |type|
        expect(negotiate(type)).to eq(described_class::RSS)
      end
    end

    it 'prefers the higher quality and, on ties, RSS', :aggregate_failures do
      expect(negotiate('application/json;q=0.9, application/xml;q=0.8')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/json;q=0.8, application/xml;q=0.9')).to eq(described_class::RSS)
      expect(negotiate('application/json, application/xml')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/xml, application/json')).to eq(described_class::RSS)
      expect(negotiate('application/json;q=0.5, application/xml;q=0.5')).to eq(described_class::JSON_FEED)
    end

    it 'prefers more specific ranges at equal quality', :aggregate_failures do
      expect(negotiate('*/*, application/json')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/*, application/xml')).to eq(described_class::RSS)
      expect(negotiate('*/*')).to eq(described_class::RSS)
      expect(negotiate('application/*')).to eq(described_class::RSS)
    end

    it 'ignores ranges with q=0', :aggregate_failures do
      expect(negotiate('application/json;q=0')).to eq(described_class::RSS)
      expect(negotiate('application/json;q=0, application/xml')).to eq(described_class::RSS)
      expect(negotiate('application/xml;q=0, application/json')).to eq(described_class::JSON_FEED)
    end

    it 'clamps and tolerates malformed quality values', :aggregate_failures do
      expect(negotiate('application/json;q=5, application/xml;q=1')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/json;q=-1')).to eq(described_class::RSS)
      expect(negotiate('application/json;q=abc, application/xml;q=0.5')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/json;charset=utf-8')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/json;foo=1;q=0.2, application/xml;q=0.3')).to eq(described_class::RSS)
    end

    it 'skips malformed ranges', :aggregate_failures do
      expect(negotiate('json, /, application/, /json, application/json')).to eq(described_class::JSON_FEED)
      expect(negotiate('json')).to eq(described_class::RSS)
      expect(negotiate(',,')).to eq(described_class::RSS)
    end

    it 'maps path extensions regardless of Accept', :aggregate_failures do
      expect(negotiate('application/json', path: '/f.rss')).to eq(described_class::RSS)
      expect(negotiate('application/json', path: '/f.xml')).to eq(described_class::RSS)
      expect(negotiate(nil, path: '/f.json')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/json', path: '/f.jsonx')).to eq(described_class::JSON_FEED)
      expect(negotiate('application/xml', path: '/f.json.bak')).to eq(described_class::RSS)
    end
  end

  describe '.request_path' do
    it 'returns PATH_INFO as a string', :aggregate_failures do
      expect(described_class.request_path(rack_request(path: '/a/b.json'))).to eq('/a/b.json')
      expect(described_class.request_path(Rack::Request.new({}))).to eq('')
    end
  end

  describe '.content_type' do
    it 'maps formats to HTTP content types', :aggregate_failures do
      expect(described_class.content_type(described_class::JSON_FEED)).to eq('application/feed+json')
      expect(described_class.content_type(described_class::RSS)).to eq('application/xml')
    end
  end

  describe '.strip_known_extension (edges)' do
    it 'strips only a trailing known suffix, once', :aggregate_failures do
      expect(described_class.strip_known_extension('feed.xml')).to eq('feed')
      expect(described_class.strip_known_extension('feed.json.rss')).to eq('feed.json')
      expect(described_class.strip_known_extension('feed.json.bak')).to eq('feed.json.bak')
      expect(described_class.strip_known_extension(nil)).to eq('')
      expect(described_class.strip_known_extension(:'a.json')).to eq('a')
    end
  end

  describe Html2rss::Web::Feeds::FormatNegotiation::MediaRange do
    def range(type, subtype, quality: 1.0, position: 0)
      described_class.new(type:, subtype:, quality:, position:)
    end

    it 'ranks specificity', :aggregate_failures do
      expect(range('*', '*').specificity).to eq(0)
      expect(range('application', '*').specificity).to eq(1)
      expect(range('application', 'json').specificity).to eq(2)
      expect(range('*', 'json').specificity).to eq(2)
    end

    it 'matches candidates case-insensitively', :aggregate_failures do
      expect(range('*', '*').matches?('application/json')).to be(true)
      expect(range('application', '*').matches?('Application/JSON')).to be(true)
      expect(range('application', '*').matches?('text/xml')).to be(false)
      expect(range('application', 'json').matches?('APPLICATION/JSON')).to be(true)
      expect(range('application', 'json').matches?('application/xml')).to be(false)
      expect(range('text', 'json').matches?('application/json')).to be(false)
    end
  end
end
