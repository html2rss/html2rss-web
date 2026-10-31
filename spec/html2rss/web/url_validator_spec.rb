# frozen_string_literal: true

RSpec.describe Html2rss::Web::UrlValidator do
  describe '.canonical_url' do
    it 'normalizes scheme-qualified URLs', :aggregate_failures do
      expect(described_class.canonical_url('http://example.com')).to eq('http://example.com/')
      expect(described_class.canonical_url('https://Example.com/a#frag')).to eq('https://example.com/a#frag')
      expect(described_class.canonical_url('https://example.com:8443/p?q=1')).to eq('https://example.com:8443/p?q=1')
    end

    it 'returns nil for non-strings and empty strings', :aggregate_failures do
      expect(described_class.canonical_url(nil)).to be_nil
      expect(described_class.canonical_url(:'https://example.com')).to be_nil
      expect(described_class.canonical_url('')).to be_nil
    end

    it 'returns nil for unsupported or malformed URLs', :aggregate_failures do
      ['ftp://example.com', 'example.com', 'javascript:alert(1)', 'not a url', 'https://user:pw@example.com/x']
        .each { |url| expect(described_class.canonical_url(url)).to be_nil }
    end

    it 'accepts URLs of exactly MAX_URL_LENGTH and rejects longer ones', :aggregate_failures do
      prefix = 'https://example.com/'
      at_limit = prefix + ('a' * (described_class::MAX_URL_LENGTH - prefix.length))

      expect(at_limit.length).to eq(described_class::MAX_URL_LENGTH)
      expect(described_class.canonical_url(at_limit)).to eq(at_limit)
      expect(described_class.canonical_url("#{at_limit}a")).to be_nil
    end
  end

  describe '.valid_url?' do
    it 'is true for valid URLs and false otherwise', :aggregate_failures do
      expect(described_class.valid_url?('https://example.com')).to be(true)
      expect(described_class.valid_url?('ftp://example.com')).to be(false)
      expect(described_class.valid_url?(nil)).to be(false)
    end
  end

  describe '.url_allowed?' do
    let(:url) { 'https://example.com/articles' }

    def allowed?(patterns, target = url, account: nil)
      described_class.url_allowed?(account || { username: 'u', allowed_urls: patterns }, target)
    end

    it 'denies URL access when account has no allowed URLs', :aggregate_failures do
      expect(allowed?([])).to be(false)
      expect(described_class.url_allowed?({ username: 'u' }, url)).to be(false)
      expect(described_class.url_allowed?({ username: 'u', allowed_urls: nil }, url)).to be(false)
    end

    it 'denies a missing account or url', :aggregate_failures do
      expect(described_class.url_allowed?(nil, url)).to be(false)
      expect(described_class.url_allowed?({ allowed_urls: ['*'] }, nil)).to be(false)
    end

    it 'denies invalid URLs even with wildcard access', :aggregate_failures do
      expect(allowed?(['*'], 'ftp://example.com')).to be(false)
      expect(allowed?(['*'], '')).to be(false)
    end

    it 'allows wildcard access when account explicitly includes *' do
      expect(allowed?(['*'])).to be(true)
    end

    it 'accepts a single non-array allowed URL' do
      expect(described_class.url_allowed?({ allowed_urls: url }, url)).to be(true)
    end

    it 'matches exact patterns by identity and by canonical form', :aggregate_failures do
      expect(allowed?(['https://example.com/articles'])).to be(true)
      expect(allowed?(['https://EXAMPLE.com/articles'])).to be(true)
      expect(allowed?(['https://example.com/other'])).to be(false)
    end

    it 'does not treat an uncanonicalizable exact pattern as a match', :aggregate_failures do
      expect(allowed?(['not a url'])).to be(false)
      expect(allowed?(['ftp://example.com/articles'])).to be(false)
    end

    it 'matches wildcard patterns case-insensitively against the canonical URL', :aggregate_failures do
      expect(allowed?(['https://example.com/*'])).to be(true)
      expect(allowed?(['HTTPS://EXAMPLE.COM/*'])).to be(true)
      expect(allowed?(['https://*.example.com/*'])).to be(false)
      expect(allowed?(['https://other.com/*'])).to be(false)
    end

    it 'treats ? and [ as literals unless the pattern contains *', :aggregate_failures do
      expect(allowed?(['https://example.com/articl?s'])).to be(false)
      expect(allowed?(['https://example.com/[a]rticles'])).to be(false)
      expect(allowed?(['https://example.com/articl?s*'])).to be(true)
    end

    it 'accepts String subclasses' do
      expect(described_class.canonical_url(Class.new(String).new('https://example.com/'))).to eq('https://example.com/')
    end

    it 'matches when any pattern matches', :aggregate_failures do
      expect(allowed?(['https://other.com/*', 'https://example.com/articles'])).to be(true)
      expect(allowed?(['https://other.com/*', 'https://another.com/x'])).to be(false)
    end

    it 'matches the canonical form of the requested url', :aggregate_failures do
      expect(allowed?(['http://example.com/'], 'http://example.com')).to be(true)
      expect(allowed?(['http://example.com/*'], 'http://Example.com')).to be(true)
    end
  end
end
