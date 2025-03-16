# frozen_string_literal: true

require 'ssrf_filter'
require 'html2rss'
require_relative '../app/local_config'

module Html2rss
  module Web
    ##
    # Strategy to fetch a URL using the SSRF filter.
    class SsrfFilterStrategy < Html2rss::RequestService::Strategy
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
