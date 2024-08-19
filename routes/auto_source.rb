# frozen_string_literal: true

require 'addressable'
require 'base64'
require 'ssrf_filter'
require 'html2rss'

module Html2rss
  module Web
    class App
      if ENV['AUTO_SOURCE_ENABLED'].to_s == 'true'

        hash_branch 'auto_source' do |r|
          with_basic_auth(realm: 'Auto Source',
                          username: ENV.fetch('AUTO_SOURCE_USERNAME'),
                          password: ENV.fetch('AUTO_SOURCE_PASSWORD')) do
            r.root do
              view 'index', layout: '/layout'
            end

            r.on String, method: :get do |encoded_url|
              rss = build_auto_source_from_encoded_url(encoded_url)

              HttpCache.expires(response, ttl_in_seconds(rss), cache_control: 'private, must-revalidate')

              response['Content-Type'] = CONTENT_TYPE_RSS

              rss.to_s
            end
          end
        end

        private

        def build_auto_source_from_encoded_url(encoded_url)
          url = Addressable::URI.parse Base64.urlsafe_decode64(encoded_url)
          request = SsrfFilter.get(url)
          headers = request.to_hash.transform_values(&:first)

          auto_source = Html2rss::AutoSource.new(url, body: request.body, headers:)

          auto_source.channel.stylesheets << Html2rss::RssBuilder::Stylesheet.new(href: './rss.xsl', type: 'text/xsl')

          auto_source.build
        end

        def ttl_in_seconds(rss, default_in_minutes: 60)
          (rss.channel.ttl || default_in_minutes) * 60
        end

      else
        # auto_source feature is disabled
        hash_branch 'auto_source' do |r|
          r.on do
            response.status = 403
            'The auto source feature is disabled.'
          end
        end
      end
    end
  end
end
