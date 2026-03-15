# frozen_string_literal: true

require 'spec_helper'

require_relative '../../../app/web/security/feed_access'

RSpec.describe Html2rss::Web::FeedAccess do
  describe '.url_allowed_for_username?' do
    it 'returns true when the user account allows the URL' do
      account = { username: 'alice', allowed_urls: ['https://example.com/*'] }
      allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username).with('alice').and_return(account)

      expect(described_class.url_allowed_for_username?('alice', 'https://example.com/articles')).to be(true)
    end

    it 'returns false when the user account is missing' do
      allow(Html2rss::Web::AccountManager).to receive(:get_account_by_username).with('missing').and_return(nil)

      expect(described_class.url_allowed_for_username?('missing', 'https://example.com/articles')).to be(false)
    end
  end
end
