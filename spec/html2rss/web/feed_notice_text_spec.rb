# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app'

RSpec.describe Html2rss::Web::FeedNoticeText do
  describe '.empty_feed_item' do
    subject(:message) { described_class.empty_feed_item(url: 'https://example.com/articles') }

    it 'includes actionable product guidance' do
      expect(message).to include('What you can do:')
      expect(message).to include('Try again in a few moments')
    end

    it 'does not mention hidden strategy controls' do
      expect(message).not_to include('browserless strategy')
      expect(message).not_to include('Try another strategy')
    end
  end
end
