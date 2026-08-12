# frozen_string_literal: true

module FeedRendererHelpers
  # Stubs successful feed bodies for request/integration specs that isolate Service output.
  # Success HTTP envelopes (status, Content-Type, cache, Link) come from Renderer itself.
  #
  # @param rss_body [String]
  # @param json_body [String]
  # @return [void]
  def stub_feed_renderer(rss_body: '<rss version="2.0"></rss>',
                         json_body: '{"version":"https://jsonfeed.org/version/1.1","items":[]}')
    allow(Html2rss::Web::Feeds::Renderer).to receive(:render).and_wrap_original do |original, result, **kwargs|
      response = kwargs.fetch(:response)
      request = kwargs.fetch(:request)
      next original.call(result, response: response, request: request) unless result.status == :ok

      format = Html2rss::Web::Feeds::FormatNegotiation.format_for_request(request)
      Html2rss::Web::Feeds::Renderer.send(:apply_response_envelope, response, result, format, request)
      format == Html2rss::Web::Feeds::FormatNegotiation::JSON_FEED ? json_body : rss_body
    end
  end

  # @param feed [Html2rss::FeedResult]
  # @return [Html2rss::Web::Feeds::Contracts::RenderResult]
  def ok_render_result(feed:, cache_key: 'feed_result:test', url: 'https://example.com/articles') # rubocop:disable Metrics/MethodLength
    Html2rss::Web::Feeds::Contracts::RenderResult.new(
      status: :ok,
      payload: Html2rss::Web::Feeds::Contracts::RenderPayload.new(
        feed: feed,
        site_title: 'Example Feed',
        url: url
      ),
      message: nil,
      ttl_seconds: 600,
      cache_key: cache_key,
      error_message: nil,
      empty_reason: nil
    )
  end

  # @return [Html2rss::FeedResult]
  def link_header_feed_double # rubocop:disable Metrics/MethodLength
    feed = instance_double(
      Html2rss::FeedResult,
      empty?: false,
      to_rss: instance_double(RSS::Rss, to_s: '<rss version="2.0"><channel><title>Example</title></channel></rss>')
    )
    allow(feed).to receive(:to_json_feed).and_return(
      version: 'https://jsonfeed.org/version/1.1',
      title: 'Example',
      items: []
    )
    feed
  end
end

RSpec.configure do |config|
  config.include FeedRendererHelpers
end
