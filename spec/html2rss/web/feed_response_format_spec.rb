# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::FeedResponseFormat do
  describe '.from_path' do
    it 'resolves format from path suffix', :aggregate_failures do
      expect(described_class.from_path('/feed.json')).to eq(:json_feed)
      expect(described_class.from_path('/feed.rss')).to eq(:rss)
      expect(described_class.from_path('/feed.xml')).to eq(:rss)
      expect(described_class.from_path('/feed')).to be_nil
    end
  end

  describe '.strip_known_extension' do
    it 'removes known extensions', :aggregate_failures do
      expect(described_class.strip_known_extension('/feed.json')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed.rss')).to eq('/feed')
      expect(described_class.strip_known_extension('/feed')).to eq('/feed')
    end
  end

  describe '.content_type' do
    it 'returns proper HTTP header string', :aggregate_failures do
      expect(described_class.content_type(:json_feed)).to eq('application/feed+json')
      expect(described_class.content_type(:rss)).to eq('application/xml')
    end
  end

  describe '.from_accept' do
    subject(:from_accept) { described_class.from_accept(accept_header) }

    context 'when wildcard media types are present' do
      let(:accept_header) { 'application/feed+json;q=0.8, */*;q=0.2' }

      it 'prefers the more specific json feed match' do
        expect(from_accept).to eq(:json_feed)
      end
    end

    context 'when json feed is explicitly refused' do
      let(:accept_header) { 'application/feed+json;q=0, application/xml;q=0.4' }

      it 'falls back to rss negotiation' do
        expect(from_accept).to be_nil
      end
    end

    context 'when rss is explicitly refused' do
      let(:accept_header) { 'application/xml;q=0, application/feed+json;q=0.4' }

      it 'returns json feed' do
        expect(from_accept).to eq(:json_feed)
      end
    end
  end
end
