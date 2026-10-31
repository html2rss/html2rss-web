# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Html2rss::Web::Feeds::Cache do
  attr_writer :fetch_calls

  let(:result) do
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(
        feed: Object.new,
        site_title: 'Example',
        url: 'https://example.com'
      ),
      ttl_seconds: 60,
      cache_key: 'feed_result:test',
      error_message: nil,
      empty_reason: nil
    )
  end

  before do
    described_class.clear!
  end

  it 'returns the cached result on repeated reads for the same key', :aggregate_failures do
    miss, hit = read_same_key_twice

    expect(miss).to eq(result)
    expect(hit).to eq(result.with(cache_hit: true))
  end

  it 'rebuilds after the cache is cleared' do
    fetch_with_counter
    described_class.clear!(reason: 'spec')

    expect { fetch_with_counter }.to change { fetch_calls }.from(1).to(2)
  end

  it 'coalesces concurrent in-flight reads for the same key to a single computation' do
    results, calls = run_concurrent_fetches('feed_result:concurrent_test', 5)

    expect(results).to all(eq(result))
    expect(calls).to eq(1)
  end

  it 'propagates cancellation and cleans in-flight entry when the leader is stopped',
     :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    waiter_error = nil

    Async do |task|
      task.async do
        described_class.fetch('feed_result:stopped_test', ttl_seconds: 60) do
          sleep 5
          result
        end
      end
      task.yield
      waiter = task.async do
        described_class.fetch('feed_result:stopped_test', ttl_seconds: 60) { result }
      rescue Exception => error # rubocop:disable Lint/RescueException
        waiter_error = error
      end
      task.children.first.stop
      waiter.wait
    end

    expect(waiter_error).to be_a(Exception)
    expect(described_class.const_get(:IN_FLIGHT)).to be_empty
  end

  describe '.seconds_from_minutes' do
    it 'converts positive minute values to seconds', :aggregate_failures do
      expect(described_class.seconds_from_minutes(5)).to eq(300)
      expect(described_class.seconds_from_minutes('10')).to eq(600)
    end

    it 'falls back to default for nil or non-positive values', :aggregate_failures do
      expect(described_class.seconds_from_minutes(nil)).to eq(3600)
      expect(described_class.seconds_from_minutes(0)).to eq(3600)
      expect(described_class.seconds_from_minutes(-5)).to eq(3600)
      expect(described_class.seconds_from_minutes('invalid', default: 300)).to eq(300)
    end
  end

  describe '.fetch (freshness and ttl)' do
    let(:now) { Time.now.utc }

    before { allow(Time).to receive(:now).and_return(now) }

    def fetch_at(time, key: 'k', ttl: 60)
      allow(Time).to receive(:now).and_return(time)
      calls = 0
      value = described_class.fetch(key, ttl_seconds: ttl) { (calls += 1) && result }
      [value, calls]
    end

    it 'marks only cached reads as cache hits', :aggregate_failures do
      miss, = fetch_at(now)
      hit, = fetch_at(now)

      expect(miss.cache_hit).to be(false)
      expect(hit.cache_hit).to be(true)
    end

    it 'is fresh strictly before expires_at and stale at it', :aggregate_failures do
      fetch_at(now)

      expect(fetch_at(now + 59).last).to eq(0)
      expect(fetch_at(now + 60).last).to eq(1)
    end

    it 'falls back to the default ttl for blank or non-positive ttls', :aggregate_failures do
      [nil, 0, -5, 'x'].each_with_index do |ttl, i|
        fetch_at(now, key: "k#{i}", ttl:)
        expect(fetch_at(now + 3599, key: "k#{i}", ttl:).last).to eq(0)
        expect(fetch_at(now + 3600, key: "k#{i}", ttl:).last).to eq(1)
      end
    end

    it 'accepts numeric-string ttls' do
      fetch_at(now, ttl: '30')

      expect(fetch_at(now + 30, ttl: '30').last).to eq(1)
    end

    it 'emits a write event with a 12-character key hash', :aggregate_failures do
      allow(Html2rss::Web::Observability).to receive(:emit)
      fetch_at(now, key: 'abc')

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'cache.lifecycle', outcome: 'success', level: :info,
        details: { component: 'feeds_cache', event: 'write', key_hash: Digest::SHA256.hexdigest('abc')[0..11] }
      )
    end
  end

  describe '.fetch (cacheable)' do
    it 'does not cache when cacheable is false', :aggregate_failures do
      2.times do
        described_class.fetch('k', ttl_seconds: 60, cacheable: false) do
          self.fetch_calls += 1
          result
        end
      end

      expect(fetch_calls).to eq(2)
      expect(described_class.const_get(:ENTRIES)).to be_empty
    end

    it 'consults a cacheable proc with the result', :aggregate_failures do
      seen = []
      predicate = lambda do |value|
        seen << value
        false
      end
      described_class.fetch('k', ttl_seconds: 60, cacheable: predicate) { result }

      expect(seen).to eq([result])
      expect(described_class.const_get(:ENTRIES)).to be_empty
    end

    it 'caches when the proc returns true' do
      described_class.fetch('k', ttl_seconds: 60, cacheable: ->(_r) { true }) { result }

      expect(described_class.const_get(:ENTRIES)).to have_key('k')
    end
  end

  describe '.fetch (failures and coalescing)' do
    it 'propagates errors, caches nothing and clears the in-flight slot', :aggregate_failures do
      expect { described_class.fetch('k', ttl_seconds: 60) { raise ArgumentError, 'boom' } }
        .to raise_error(ArgumentError, 'boom')
      expect(described_class.const_get(:ENTRIES)).to be_empty
      expect(described_class.const_get(:IN_FLIGHT)).to be_empty
    end

    # rubocop:disable-next RSpec/ExampleLength
    it 'shares the leader error with coalesced waiters', :aggregate_failures do
      errors = []
      Async do |task|
        Array.new(2) do
          task.async do
            described_class.fetch('k', ttl_seconds: 60) do
              sleep 0.05
              raise ArgumentError, 'boom'
            end
          rescue ArgumentError => error
            errors << error.message
          end
        end.each(&:wait)
      end

      expect(errors).to eq(%w[boom boom])
    end

    it 'returns the same result object to coalesced waiters', :aggregate_failures do
      results, calls = run_concurrent_fetches('k', 3)

      expect(calls).to eq(1)
      expect(results.uniq.size).to eq(1)
    end

    it 'lets a waiter that arrives after completion read the finished job', :aggregate_failures do
      job = described_class.const_get(:InFlight).new
      job.success!(:done)
      failed = described_class.const_get(:InFlight).new
      failed.failure!(ArgumentError.new('late'))

      expect(job.wait).to eq(:done)
      expect { failed.wait }.to raise_error(ArgumentError, 'late')
    end
  end

  describe '.clear!' do
    it 'empties entries and in-flight jobs, emits a reload event and returns nil', :aggregate_failures do
      allow(Html2rss::Web::Observability).to receive(:emit)
      fetch_with_counter

      expect(described_class.clear!(reason: 'spec')).to be_nil
      expect(described_class.const_get(:ENTRIES)).to be_empty
      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        event_name: 'cache.lifecycle', outcome: 'success', level: :info,
        details: { component: 'feeds_cache', event: 'clear', reason: 'spec' }
      )
    end

    it 'defaults the reason to manual' do
      allow(Html2rss::Web::Observability).to receive(:emit)
      described_class.clear!

      expect(Html2rss::Web::Observability).to have_received(:emit).with(
        hash_including(details: hash_including(reason: 'manual'))
      )
    end
  end

  describe 'pruning' do
    let(:now) { Time.now.utc }

    before do
      allow(Html2rss::Web::Flags).to receive(:feeds_cache_max_size).and_return(10)
      allow(Time).to receive(:now).and_return(now)
    end

    def fill(count, ttl: 100)
      count.times { |i| described_class.fetch("k#{i}", ttl_seconds: ttl + i) { result } }
    end

    def keys = described_class.const_get(:ENTRIES).keys

    it 'does not prune below the max size', :aggregate_failures do
      fill(9)
      described_class.fetch('extra', ttl_seconds: 1) { result }

      expect(keys.size).to eq(10)
    end

    it 'prunes expired entries first and keeps the rest when that is enough', :aggregate_failures do
      fill(10, ttl: 10)
      allow(Time).to receive(:now).and_return(now + 10)
      described_class.fetch('fresh', ttl_seconds: 100) { result }

      expect(keys).to eq(%w[k1 k2 k3 k4 k5 k6 k7 k8 k9 fresh])
    end

    it 'evicts the soonest-expiring entries down to 90% of max when still full', :aggregate_failures do
      fill(10)
      described_class.fetch('extra', ttl_seconds: 1000) { result }

      expect(keys.size).to eq(10)
      expect(keys).not_to include('k0')
      expect(keys).to include('extra', 'k9')
    end
  end

  private

  # @return [Array<Html2rss::Web::Feeds::Contracts::RenderResult>]
  def read_same_key_twice
    [fetch_with_counter, fetch_with_counter]
  end

  # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
  def fetch_with_counter
    described_class.fetch('feed_result:test', ttl_seconds: 60) do
      self.fetch_calls += 1
      result
    end
  end

  # @return [Integer]
  def fetch_calls
    @fetch_calls ||= 0
  end

  def run_concurrent_fetches(key, concurrency) # rubocop:disable Metrics/MethodLength
    calls = 0
    results = []
    Async do |task|
      Array.new(concurrency) do
        task.async do
          results << described_class.fetch(key, ttl_seconds: 60) do
            calls += 1
            sleep 0.05
            result
          end
        end
      end.each(&:wait)
    end
    [results, calls]
  end
end
