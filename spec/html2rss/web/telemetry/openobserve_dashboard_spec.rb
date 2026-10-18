# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe 'OpenObserve ops dashboard' do
  let(:root) { File.expand_path('../../../..', __dir__) }
  let(:raw) { File.read(File.join(root, 'docs/observability/html2rss-web.ops.dashboard.json')) }
  let(:dashboard) { JSON.parse(raw) }

  def panels
    dashboard.fetch('tabs').fetch(0).fetch('panels')
  end

  def panel_named(title)
    panels.find { |panel| panel.fetch('title') == title }
  end

  def query_text(panel)
    panel.fetch('queries').map { |query| query.fetch('query') }.join("\n")
  end

  def sql_queries
    panels.flat_map { |panel| panel.fetch('queries') }
          .reject { |query| query.dig('fields', 'stream_type') == 'metrics' }
          .map { |query| query.fetch('query') }
  end

  def metric_queries
    panels.flat_map { |panel| panel.fetch('queries') }
          .select { |query| query.dig('fields', 'stream_type') == 'metrics' }
          .map { |query| query.fetch('query') }
  end

  it 'is one board' do
    expect(dashboard).to be_a(Hash)
    expect(dashboard.fetch('tabs').size).to eq(1)
  end

  it 'lives in the default folder' do
    expect(dashboard.fetch('folder')).to eq('default')
  end

  it 'covers the last 24 hours' do
    expect(dashboard.fetch('defaultDatetimeDuration')).to include(
      'type' => 'relative',
      'relativeTimePeriod' => '24h'
    )
  end

  it 'uses schema version 8 and names html2rss-web' do
    expect(dashboard.fetch('version')).to eq(8)
    expect(dashboard.fetch('title')).to include('html2rss-web')
  end

  it 'fills each row of the 192-wide grid' do
    edges = panels.map { |panel| panel.dig('layout', 'x') + panel.dig('layout', 'w') }

    expect(edges.uniq).to eq([192])
  end

  it 'has no threshold key' do
    expect(raw).not_to match(/"threshold"\s*:/)
  end

  it 'keeps SQL queries aggregate and off log body and message' do
    expect(sql_queries).to all(match(/count\(|approx_percentile_cont\(/))
    expect(sql_queries.join("\n")).not_to match(/\b(?:body|message)\b/)
  end

  it 'aliases every histogram timestamp as x_axis_1' do
    expect(sql_queries).to all(include('histogram(_timestamp) AS x_axis_1', 'GROUP BY x_axis_1'))
  end

  it 'filters logs and traces to this service on stream html2rss_web' do
    expect(sql_queries).to all(include("service_name = 'html2rss-web'", '"html2rss_web"'))
  end

  it 'filters metrics with PromQL service_name' do
    expect(metric_queries).to all(include('service_name="html2rss-web"'))
    expect(metric_queries).not_to include(a_string_including('html2rss_web'))
  end

  it 'charts log lines per minute' do
    query = query_text(panel_named('Log lines per minute'))

    expect(query).to include('count(*)', 'histogram(_timestamp) AS x_axis_1')
  end

  it 'charts spans per minute and error spans' do
    query = query_text(panel_named('Spans per minute'))

    expect(query).to include('count(*) AS spans', 'count(*) AS error_spans', "span_status = 'ERROR'")
  end

  it 'splits render outcomes per minute by result and reason' do
    query = query_text(panel_named('Render outcomes per minute'))

    expect(query).to include(
      'sum by (result, reason)',
      'increase(',
      'operation="feed.render"',
      'hit',
      'success'
    )
  end

  it 'charts create failures per minute' do
    query = query_text(panel_named('Create failures per minute'))

    expect(query).to include('increase(', 'operation="feed.create"', 'result="failure"')
  end

  it 'charts render and create server-span p95 latency in milliseconds' do
    query = query_text(panel_named('Render and create server-span p95 latency'))

    expect(query).to include("span_kind = '2'", 'approx_percentile_cont(duration, 0.95) / 1000')
    expect(query).to include('feed.render', 'feed.create')
  end

  it 'charts 5xx server spans outside route group health' do
    panel = panel_named('5xx server spans')

    expect(query_text(panel)).to include("span_kind = '2'", "html2rss_route_group != 'health'", '>= 500')
    expect(panel.fetch('description')).to include(
      '/api/v1/health/live',
      '/api/v1/health/ready',
      '/api/v1/health',
      '/metrics'
    )
  end

  it 'charts html2rss_up with a gauge aggregation' do
    expect(query_text(panel_named('html2rss_up'))).to match(/max\(|avg\(/)
  end

  it 'charts build revision with a gauge aggregation' do
    expect(query_text(panel_named('Build revision'))).to include('html2rss_build_info').and match(/max\(|avg\(/)
  end

  it 'charts request.fault as a counter' do
    expect(query_text(panel_named('request.fault'))).to include('increase(', 'operation="request.fault"')
  end

  it 'uses underscore span attribute columns' do
    joined = sql_queries.join("\n")

    expect(joined).to include(
      'html2rss_operation',
      'html2rss_result',
      'html2rss_reason',
      'html2rss_route_group'
    )
    expect(joined).not_to include('html2rss.operation', 'html2rss.result', 'html2rss.reason', 'html2rss.route_group')
  end

  it 'aggregates counters with increase or rate' do
    counters = metric_queries.grep(/html2rss_outcome_total/)

    expect(counters).to all(match(/increase\(|rate\(/))
  end

  it 'does not sum a cumulative counter inside a time bucket' do
    expect(raw).not_to match(/sum\s*\(\s*value\s*\)/i)
  end

  it 'does not mention host signals, Pushover, or an alert destination' do
    expect(raw.downcase).not_to match(/cpu|memory|disk|network|pushover|alert/)
  end
end
