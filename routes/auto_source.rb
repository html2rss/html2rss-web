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
            r.on String, method: :get do |encoded_url|
              url = Addressable::URI.parse(Base64.urlsafe_decode64(encoded_url))

              rss = Html2rss::AutoSource.build_from_response(SsrfFilter.get(url), url)

              max_age = (rss.channel.ttl || 60) * 60

              HttpCache.expires(response, max_age, cache_control: 'private, must-revalidate')

              response['Content-Type'] = 'application/rss+xml'

              rss.to_s
            end
          end
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
