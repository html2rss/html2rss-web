# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Feeds::LastResults do
  before { described_class.clear! }

  let(:ok_result) do
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: nil,
      ttl_seconds: 60,
      cache_key: 'k'
    )
  end

  it 'returns unknown until recorded' do
    expect(described_class['missing']).to eq(Html2rss::Web::Feeds::LastResult.unknown)
  end

  it 'records render outcomes with an injectable clock', :aggregate_failures do
    at = Time.utc(2026, 8, 29, 12)
    last = described_class.record('feed.id', ok_result, clock: -> { at })

    expect(last).to have_attributes(state: :ok, code: nil, at:)
    expect(described_class['feed.id']).to eq(last)
    expect(last.to_h).to eq(state: 'ok', code: nil, at: '2026-08-29T12:00:00Z')
  end
end
