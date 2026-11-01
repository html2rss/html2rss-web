# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Api::V1::Refine::PageCache do
  let(:response) { Html2rss::RequestService::Response.new(body: '<html></html>', url: 'https://example.com/', status: 200) }
  let(:ctx) do
    instance_double(
      Html2rss::RequestService::Context,
      relation: :initial, headers: {}, request: {},
      policy: instance_double(Html2rss::RequestService::Policy, cache_key: 'policy'),
      url: instance_double(Html2rss::Url, host: 'example.com', to_s: 'https://example.com/')
    )
  end
  let(:strategy) { instance_double(Html2rss::RequestService::HttpxStrategy, execute: response) }

  before do
    Html2rss::RequestService.response_cache = nil
    allow(Html2rss::RequestService::HttpxStrategy).to receive(:new).and_return(strategy)
  end

  after { Html2rss::RequestService.response_cache = nil }

  def fetch = Html2rss::RequestService.execute(ctx, strategy: :httpx)

  it 'fetches once for repeated requests inside the scope', :aggregate_failures do
    described_class.within { 2.times { fetch } }

    expect(strategy).to have_received(:execute).once
  end

  it 'keeps the cache across scopes' do
    2.times { described_class.within { fetch } }

    expect(strategy).to have_received(:execute).once
  end

  it 'fetches live outside the scope' do
    described_class.within { fetch }
    2.times { fetch }

    expect(strategy).to have_received(:execute).exactly(3).times
  end

  it 'leaves the scope when the block raises', :aggregate_failures do
    expect { described_class.within { raise 'boom' } }.to raise_error('boom')
    2.times { fetch }

    expect(Fiber[described_class::SCOPE]).to be_nil
    expect(strategy).to have_received(:execute).twice
  end
end
