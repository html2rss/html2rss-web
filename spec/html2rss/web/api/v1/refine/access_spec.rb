# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::Refine::Access do
  let(:account) { { username: 'alice', allowed_urls: ['*'] } }
  let(:request) { refine_request({}) }

  describe '.ensure_allowed!' do
    before do
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(account)
      allow(Html2rss::Web::Flags).to receive_messages(refine_enabled?: true, auto_source_enabled?: true)
    end

    it 'returns the account authenticated from the request', :aggregate_failures do
      expect(described_class.ensure_allowed!(request)).to eq(account)
      expect(Html2rss::Web::Auth).to have_received(:authenticate).with(request)
    end

    it 'authenticates before revealing that the refine is disabled', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive(:refine_enabled?).and_return(false)
      allow(Html2rss::Web::Auth).to receive(:authenticate).and_return(nil)

      expect { described_class.ensure_allowed!(request) }
        .to raise_error(Html2rss::Web::UnauthorizedError, 'Authentication required')
    end

    it 'forbids a disabled refine' do
      allow(Html2rss::Web::Flags).to receive(:refine_enabled?).and_return(false)

      expect { described_class.ensure_allowed!(request) }
        .to raise_error(Html2rss::Web::ForbiddenError, 'Refine is disabled')
    end

    it 'requires auto-source only for live fetches', :aggregate_failures do
      allow(Html2rss::Web::Flags).to receive(:auto_source_enabled?).and_return(false)

      expect(described_class.ensure_allowed!(request)).to eq(account)
      expect(described_class.ensure_allowed!(request, live_fetch: false)).to eq(account)
      expect { described_class.ensure_allowed!(request, live_fetch: true) }
        .to raise_error(Html2rss::Web::AutoSourceDisabledError)
    end
  end

  describe '.page_url' do
    it 'canonicalizes an allowed URL' do
      expect(described_class.page_url(' https://example.com/a ', account)).to eq('https://example.com/a')
    end

    it 'trims trailing whitespace' do
      expect(described_class.page_url('https://example.com/a   ', account)).to eq('https://example.com/a')
    end

    it 'treats blank input as absent', :aggregate_failures do
      expect(described_class.page_url(nil, account)).to be_nil
      expect(described_class.page_url('  ', account)).to be_nil
    end

    it 'rejects a malformed URL' do
      expect { described_class.page_url('ftp://example.com', account) }
        .to raise_error(Html2rss::Web::BadRequestError, 'Invalid URL format')
    end

    it 'rejects a URL the account may not reach' do
      restricted = { username: 'alice', allowed_urls: ['https://other.example/*'] }

      expect { described_class.page_url('https://example.com/a', restricted) }
        .to raise_error(Html2rss::Web::ForbiddenError, 'URL not allowed for this account')
    end
  end

  describe '.page_url!' do
    it 'requires a URL', :aggregate_failures do
      expect(described_class.page_url!('https://example.com/a', account)).to eq('https://example.com/a')
      expect { described_class.page_url!('', account) }
        .to raise_error(Html2rss::Web::BadRequestError, 'URL parameter is required')
    end
  end
end
