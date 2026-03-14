# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::FeedAcceptHeader do
  describe '.preferred_format' do
    subject(:preferred_format) do
      described_class.preferred_format(
        accept_header,
        json_media_types: Html2rss::Web::FeedResponseFormat::JSON_MEDIA_TYPES,
        rss_media_types: Html2rss::Web::FeedResponseFormat::RSS_MEDIA_TYPES
      )
    end

    context 'when wildcard media types are present' do
      let(:accept_header) { 'application/feed+json;q=0.8, */*;q=0.2' }

      it 'prefers the more specific json feed match' do
        expect(preferred_format).to eq(Html2rss::Web::FeedResponseFormat::JSON_FEED)
      end
    end

    context 'when json feed is explicitly refused' do
      let(:accept_header) { 'application/feed+json;q=0, application/xml;q=0.4' }

      it 'falls back to rss negotiation' do
        expect(preferred_format).to be_nil
      end
    end

    context 'when rss is explicitly refused' do
      let(:accept_header) { 'application/xml;q=0, application/feed+json;q=0.4' }

      it 'returns json feed' do
        expect(preferred_format).to eq(Html2rss::Web::FeedResponseFormat::JSON_FEED)
      end
    end
  end
end
