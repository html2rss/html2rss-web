# frozen_string_literal: true

require_relative '../../../app/web/security/url_validator'

RSpec.describe Html2rss::Web::UrlValidator do
  describe '.url_allowed?' do
    let(:url) { 'https://example.com/articles' }

    it 'denies URL access when account has no allowed URLs' do
      account = { username: 'health-check', allowed_urls: [] }

      expect(described_class.url_allowed?(account, url)).to be(false)
    end

    it 'allows wildcard access when account explicitly includes *' do
      account = { username: 'admin', allowed_urls: ['*'] }

      expect(described_class.url_allowed?(account, url)).to be(true)
    end
  end
end
