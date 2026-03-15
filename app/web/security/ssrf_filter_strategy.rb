# frozen_string_literal: true

require 'ssrf_filter'
require 'html2rss'
module Html2rss
  module Web
    ##
    # Strategy to fetch a URL using the SSRF filter.
    class SsrfFilterStrategy < Html2rss::RequestService::Strategy
      # Executes a URL fetch through `ssrf_filter` and adapts response shape.
      #
      # @return [Html2rss::RequestService::Response]
      def execute
        headers = LocalConfig.global.fetch(:headers, {}).merge(
          ctx.headers.transform_keys(&:to_sym)
        )
        response = SsrfFilter.get(ctx.url, headers:)

        Html2rss::RequestService::Response.new(body: response.body,
                                               url: ctx.url,
                                               headers: response.to_hash.transform_values(&:first))
      end
    end
  end
end
