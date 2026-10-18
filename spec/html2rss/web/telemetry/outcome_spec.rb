# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Telemetry::Outcome do
  it 'rejects an unknown combination' do
    expect { described_class.new(operation: 'catalog.build', result: 'success', reason: 'none') }
      .to raise_error(ArgumentError, 'unknown outcome')
  end

  it 'maps an unknown classifier code to internal' do
    decision = Html2rss::Web::ErrorClassifier::Decision.new(
      status: 400,
      code: 'WHATEVER',
      message: 'nope',
      kind: 'input',
      cacheable: false,
      retryable: false,
      next_action: 'none',
      retry_action: 'none'
    )

    expect(described_class.reason_for(decision)).to eq('internal')
  end

  it 'writes the counter and the same attributes on a recording span', :aggregate_failures do
    span = RecordingSpan.new
    trace = Module.new
    trace.define_singleton_method(:current_span) { span }
    stub_const('OpenTelemetry::Trace', trace)
    allow(Html2rss::Web::Telemetry::Metrics).to receive(:increment)

    outcome = described_class.record(operation: 'feed.render', result: 'hit', reason: 'none')

    expect(Html2rss::Web::Telemetry::Metrics).to have_received(:increment).with(outcome.labels)
    expect(span.attributes).to eq(
      'html2rss.operation' => 'feed.render',
      'html2rss.result' => 'hit',
      'html2rss.reason' => 'none'
    )
  end

  it 'leaves a non-recording span unchanged' do
    span = RecordingSpan.new(recording: false)
    trace = Module.new
    trace.define_singleton_method(:current_span) { span }
    stub_const('OpenTelemetry::Trace', trace)
    allow(Html2rss::Web::Telemetry::Metrics).to receive(:increment)

    described_class.record(operation: 'feed.render', result: 'success', reason: 'none')

    expect(span.attributes).to eq({})
  end
end

##
# Captures span attributes in outcome specs.
class RecordingSpan
  attr_reader :attributes

  def initialize(recording: true)
    @recording = recording
    @attributes = {}
  end

  # @return [Boolean]
  def recording?
    @recording
  end

  # @param key [String]
  # @param value [String]
  # @return [void]
  def set_attribute(key, value)
    @attributes[key] = value
    nil
  end
end
