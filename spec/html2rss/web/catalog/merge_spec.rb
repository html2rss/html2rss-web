# frozen_string_literal: true

require 'spec_helper'

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

  describe 'local feeds' do
    # rubocop:disable-next RSpec/VerifiedDoubles
    let(:embedded) do
      double('embedded entry', to_h: {
               id: 'b.example/feed', path: '/b.example/feed.rss', source: 'embedded',
               directory: { title: 'B' }, channel: { url: 'https://b.example/' },
               parameters: { schema: {}, defaults: {} }
             })
    end
    let(:feeds) { {} }

    before do
      allow(Html2rss::Configs::Catalog).to receive(:entries).and_return([embedded])
      allow(Html2rss::Web::LocalConfig).to receive(:feeds).and_return(feeds)
    end

    def local_feed(id) = described_class.call.find { it.id == id }

    context 'with a fully described feed' do
      let(:feeds) do
        {
          a_feed: {
            directory: { title: 'My Feed', summary: 'Sum', topics: %w[news tech] },
            channel: { url: 'https://a.example/', language: 'de', title: 'Channel T' },
            parameters: { page: { default: 2 }, nodef: { type: 'string' } }
          }
        }
      end

      it 'maps directory, channel and parameter defaults', :aggregate_failures do
        entry = local_feed('a_feed')

        expect(entry).to have_attributes(
          path: '/a_feed.rss', source: 'local',
          directory: { title: 'My Feed', summary: 'Sum', topics: %w[news tech] },
          channel: { url: 'https://a.example/', language: 'de', title: 'Channel T' },
          parameters: { schema: {}, defaults: { 'page' => 2 } }
        )
      end

      it 'sorts embedded and local entries together by id', :aggregate_failures do
        expect(described_class.call.map(&:id)).to eq(%w[a_feed b.example/feed])
        expect(described_class.call.map(&:source)).to eq(%w[local embedded])
      end

      it 'joins recorded last results onto local feeds' do
        allow(Html2rss::Web::Feeds::LastResults).to receive(:[]).and_call_original
        described_class.call

        expect(Html2rss::Web::Feeds::LastResults).to have_received(:[]).with('a_feed')
        expect(Html2rss::Web::Feeds::LastResults).to have_received(:[]).with('b.example/feed')
      end
    end

    context 'with minimal directory data' do
      let(:feeds) { { 'min' => { directory: { title: 'Min' }, channel: { url: 'https://m.example/' } } } }

      it 'defaults the channel title, drops nil fields and uses empty topics', :aggregate_failures do
        entry = local_feed('min')

        expect(entry.channel).to eq(url: 'https://m.example/', title: 'Min')
        expect(entry.directory).to eq(title: 'Min', topics: [])
        expect(entry.parameters).to eq(schema: {}, defaults: {})
      end
    end

    context 'with feeds lacking a directory title' do
      let(:feeds) do
        { 'none' => { channel: { url: 'https://n.example/' } },
          'blank' => { directory: { title: '  ' }, channel: { url: 'https://n.example/' } },
          'nil' => { directory: { summary: 'x' }, channel: { url: 'https://n.example/' } } }
      end

      it 'omits them from the catalog' do
        expect(described_class.call.map(&:id)).to eq(['b.example/feed'])
      end
    end

    context 'with a directory title but no channel url' do
      let(:feeds) { { 'broken' => { directory: { title: 'T' } } } }

      it 'raises instead of publishing a channel without a url' do
        expect { described_class.call }.to raise_error(KeyError)
      end
    end
  end
end
