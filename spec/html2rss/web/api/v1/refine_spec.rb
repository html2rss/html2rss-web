# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

RSpec.describe 'api/v1 refine', openapi: { example_mode: :none }, type: :request do
  include Rack::Test::Methods

  def app = Html2rss::Web::App.freeze.app

  let(:admin_token) { 'CHANGE_ME_ADMIN_TOKEN' }
  let(:page_url) { 'https://example.com/articles' }
  let(:selectors) { { items: { selector: 'article' }, title: { selector: 'h2' } } }
  let(:refine_env) { { REFINE_ENABLED: 'true', AUTO_SOURCE_ENABLED: 'true' } }

  # @param path [String]
  # @param payload [Hash]
  # @param token [String, nil]
  def refine_post(path, payload, token: admin_token)
    header 'Authorization', token ? "Bearer #{token}" : nil
    header 'Content-Type', 'application/json'
    ClimateControl.modify(refine_env) { post "/api/v1/refine/#{path}", payload.to_json }
  end

  def data = JSON.parse(last_response.body).fetch('data')

  describe 'POST /api/v1/refine/validate', openapi: {
    summary: 'Validate refine selectors', operation_id: 'validateRefineSelectors',
    tags: ['Refine'], security: [{ 'BearerAuth' => [] }]
  } do
    it 'returns a successful report and exportable YAML', :aggregate_failures do
      refine_post('validate', { url: page_url, selectors: })

      expect(last_response.status).to eq(200)
      expect(data).to include('selectors' => JSON.parse(selectors.to_json))
      expect(data.dig('report', 'success')).to be(true)
      expect(YAML.safe_load(data.fetch('yaml'))).to include('channel' => { 'url' => page_url })
    end

    it 'reports schema failures as a 200 with issues', :aggregate_failures, openapi: false do
      refine_post('validate', { selectors: { items: { selector: '' } } })

      expect(last_response.status).to eq(200)
      expect(data).to include('selectors' => nil, 'yaml' => nil)
      expect(data.dig('report', 'success')).to be(false)
    end

    it 'requires selectors', openapi: false do
      refine_post('validate', { url: page_url })

      expect(last_response.status).to eq(400)
    end

    it 'rejects a malformed URL', openapi: false do
      refine_post('validate', { url: 'ftp://example.com', selectors: })

      expect(last_response.status).to eq(400)
    end

    it 'rejects a URL the account may not reach', openapi: false do
      allow(Html2rss::Web::UrlValidator).to receive(:url_allowed?).and_return(false)
      refine_post('validate', { url: page_url, selectors: })

      expect(last_response.status).to eq(403)
    end
  end

  describe 'POST /api/v1/refine/preview', openapi: {
    summary: 'Preview an extraction', operation_id: 'previewRefineFeed',
    tags: ['Refine'], security: [{ 'BearerAuth' => [] }]
  } do
    let(:result) do
      Html2rss::Test::Result.new(
        success: true, item_count: 2, sample_items: [{ title: 'A', url: 'https://example.com/a', published_at: nil }],
        channel_title: 'Example', channel_url: page_url, strategy_used: :faraday, duration_seconds: 0.1,
        validation_issues: nil, error_message: nil, failure_kind: nil, rss: '<rss/>',
        quality_report: nil, enhance_compare: nil, response_body: '<html/>'
      )
    end

    before { allow(Html2rss).to receive(:test).and_return(result) }

    it 'previews with the expansion serving uses, without leaking the RSS', :aggregate_failures do
      refine_post('preview', { url: page_url, selectors: })

      expect(last_response.status).to eq(200)
      expect(Html2rss).to have_received(:test)
        .with(hash_including(channel: { url: page_url }, selectors:), min_items: 1)
      expect(data).to include('item_count' => 2, 'failure_kind' => nil)
      expect(data).not_to have_key('rss')
    end

    it 'previews automatic extraction without selectors', :aggregate_failures, openapi: false do
      refine_post('preview', { url: page_url })

      expect(Html2rss).to have_received(:test).with(hash_including(auto_source: {}), min_items: 1)
    end

    it 'requires a URL', openapi: false do
      refine_post('preview', { selectors: })

      expect(last_response.status).to eq(400)
    end

    it 'needs auto-source for the live fetch', openapi: false do
      refine_env[:AUTO_SOURCE_ENABLED] = 'false'
      refine_post('preview', { url: page_url, selectors: })

      expect(last_response.status).to eq(403)
    end
  end

  describe 'POST /api/v1/refine/suggest_selectors', openapi: {
    summary: 'Suggest selectors', operation_id: 'suggestRefineSelectors',
    tags: ['Refine'], security: [{ 'BearerAuth' => [] }]
  } do
    let(:captured) do
      instance_double(
        Html2rss::Capture::CaptureResult,
        candidates: { items: [{ selector: 'article', enhance: true, sample: 'Hello', extra: 1 }],
                      title: [{ selector: 'h2', sample: 'Hello' }] },
        segment_strategy: :dom, admission_drops: { 'short' => 1 }
      )
    end

    before { allow(Html2rss).to receive(:capture).and_return(captured) }

    it 'returns ranked buckets, empty when the gem found none', :aggregate_failures do
      refine_post('suggest_selectors', { url: page_url, items_selector: ' article ' })

      expect(Html2rss).to have_received(:capture).with(page_url, strategy: :auto, items_selector: 'article')
      expect(data).to eq(
        'candidates' => {
          'items' => [{ 'selector' => 'article', 'enhance' => true, 'sample' => 'Hello' }],
          'title' => [{ 'selector' => 'h2', 'sample' => 'Hello' }], 'link' => [], 'published' => []
        },
        'segment_strategy' => 'dom', 'admission_drops' => { 'short' => 1 }
      )
    end

    it 'passes no hint when blank', openapi: false do
      refine_post('suggest_selectors', { url: page_url })

      expect(Html2rss).to have_received(:capture).with(page_url, strategy: :auto, items_selector: nil)
    end

    it 'rejects an over-long hint', openapi: false do
      refine_post('suggest_selectors', { url: page_url, items_selector: 'a' * 257 })

      expect(last_response.status).to eq(400)
    end
  end

  {
    'validate' => { selectors: { items: { selector: 'a' } } },
    'preview' => { url: 'https://example.com/articles' },
    'suggest_selectors' => { url: 'https://example.com/articles' }
  }.each do |path, payload|
    describe "POST /api/v1/refine/#{path} gating", openapi: false do
      it 'requires authentication' do
        refine_post(path, payload, token: nil)

        expect(last_response.status).to eq(401)
      end

      it 'is forbidden while the refine is disabled' do
        refine_env[:REFINE_ENABLED] = 'false'
        refine_post(path, payload)

        expect(last_response.status).to eq(403)
      end

      it 'rejects a malformed body' do
        header 'Authorization', "Bearer #{admin_token}"
        header 'Content-Type', 'application/json'
        ClimateControl.modify(refine_env) { post "/api/v1/refine/#{path}", '[1]' }

        expect(last_response.status).to eq(400)
      end
    end
  end

  it 'answers unknown refine paths with 404', openapi: false do
    refine_post('nope', {})

    expect(last_response.status).to eq(404)
  end
end
