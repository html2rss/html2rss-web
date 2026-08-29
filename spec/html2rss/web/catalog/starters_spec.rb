# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app'

RSpec.describe Html2rss::Web::Catalog::Starters do
  def entry(id, state)
    Html2rss::Web::Catalog::Entry.new(
      id:,
      path: "/#{id}.rss",
      source: 'embedded',
      directory: { title: id },
      channel: { url: "https://#{id}" },
      parameters: { schema: {}, defaults: {} },
      last_result: Html2rss::Web::Feeds::LastResult.new(state:, code: nil, at: nil)
    )
  end

  it 'prefers ok over unknown and never picks empty/error when alternatives exist', :aggregate_failures do
    entries = [
      entry('z.error', :error),
      entry('y.empty', :empty),
      entry('fao.org/newsroom', :unknown),
      entry('a.ok', :ok),
      entry('b.ok', :ok)
    ]

    expect(described_class.pick(entries)).to eq(%w[a.ok b.ok fao.org/newsroom])
  end

  it 'uses cold-seed order only as a tie-break among unknown', :aggregate_failures do
    entries = [
      entry('zzz.org/feed', :unknown),
      entry('icrc.org/news', :unknown),
      entry('fao.org/newsroom', :unknown),
      entry('ftc.gov/press-releases', :unknown)
    ]

    expect(described_class.pick(entries)).to eq(
      %w[fao.org/newsroom ftc.gov/press-releases icrc.org/news]
    )
  end

  it 'falls back to failing rows only when the catalog has nothing else' do
    entries = [entry('only.empty', :empty), entry('only.error', :error)]

    expect(described_class.pick(entries)).to eq(%w[only.empty only.error])
  end
end
