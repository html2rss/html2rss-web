# frozen_string_literal: true

require_relative '../app/http_cache'
require_relative '../helpers/auto_source'
require 'html2rss'

module Html2rss
  module Web
    class App
      # rubocop:disable Metrics/BlockLength
      hash_branch 'auto_source' do |r|
        with_basic_auth(realm: 'Auto Source',
                        username: AutoSource.username,
                        password: AutoSource.password) do
          AutoSource.check_request_origin!(request, response)

          if AutoSource.enabled?
            r.root do
              view 'index', layout: '/layout'
            end

            r.on String, method: :get do |encoded_url|
              strategy = (request.params['strategy'] || :ssrf_filter).to_sym

              url = Addressable::URI.parse(Base64.urlsafe_decode64(encoded_url))

              feed = Html2rss.feed(stylesheets: [{ href: '/rss.xsl', type: 'text/xsl' }],
                                   strategy:,
                                   channel: { url: url.to_s },
                                   auto_source: {})

              HttpCache.expires(response, AutoSource.ttl_in_seconds(feed), cache_control: 'private, must-revalidate')

              response['Content-Type'] = CONTENT_TYPE_RSS
              response.status = 200
              feed.to_xml
            end
          else
            # auto_source feature is disabled
            r.on do
              response.status = 400
              'The auto source feature is disabled.'
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
