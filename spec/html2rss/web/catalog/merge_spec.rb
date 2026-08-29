# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Catalog::Merge do
  before { Html2rss::Web::Feeds::LastResults.clear! }

  it 'returns Catalog::Entry rows with required last_result', :aggregate_failures do
    entries = described_class.call

    expect(entries).to all(be_a(Html2rss::Web::Catalog::Entry))
    expect(entries.map(&:id)).to include('fao.org/newsroom', 'ftc.gov/press-releases', 'icrc.org/news')
    expect(entries.first.last_result).to eq(Html2rss::Web::Feeds::LastResult.unknown)
    expect(entries.first.to_h.fetch(:last_result)).to eq(state: 'unknown', code: nil, at: nil)
  end

  it 'joins recorded LastResults onto matching ids' do
    render = Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: nil,
      ttl_seconds: 60,
      cache_key: 'k',
      decision: nil
    )
    Html2rss::Web::Feeds::LastResults.record('fao.org/newsroom', render, clock: -> { Time.utc(2026, 8, 29, 8) })

    entry = described_class.call.find { it.id == 'fao.org/newsroom' }
    expect(entry.last_result).to have_attributes(state: :ok, code: nil)
    expect(entry.last_result.at).to eq(Time.utc(2026, 8, 29, 8))
  end
end
