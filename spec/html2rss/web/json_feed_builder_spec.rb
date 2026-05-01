# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::JsonFeedBuilder do
  describe '.build_empty_feed_warning' do
    subject(:payload) do
      JSON.parse(
        described_class.build_empty_feed_warning(
          url: 'https://example.com/articles',
          strategy: 'faraday',
          site_title: 'Example Site'
        )
      )
    end

    it 'uses updated channel description copy' do
      expect(payload.fetch('description')).to include('We could not extract entries')
      expect(payload.fetch('description')).not_to include('different parser')
    end

    it 'uses updated item title and content text' do
      first_item = payload.fetch('items').first
      expect(first_item.fetch('title')).to eq('Preview unavailable for this source')
      expect(first_item.fetch('content_text')).to include('What you can do:')
    end

    it 'does not mention hidden strategy controls in item text' do
      first_item = payload.fetch('items').first
      expect(first_item.fetch('content_text')).not_to include('browserless strategy')
    end
  end
end
