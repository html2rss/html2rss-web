# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

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

  describe '.strip_known_extension' do
    it 'removes known extensions', :aggregate_failures do
      expect(described_class.strip_known_extension('/feed.json')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed.rss')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed')).to eq('/feed')
    end
  end
end
