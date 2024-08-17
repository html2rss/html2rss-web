# frozen_string_literal: true

require 'base64'

module Html2rss
  module Web
    class App
      if ENV['AUTO_SOURCE_ENABLED'].to_s == 'true'
        hash_branch 'auto_source' do |r|
          with_basic_auth(realm: 'Auto Source',
                          username: ENV.fetch('AUTO_SOURCE_USERNAME'),
                          password: ENV.fetch('AUTO_SOURCE_PASSWORD')) do
            r.get 'test' do |_r|
              'AUTO'
            end

            r.on String, method: :get do |encoded_url|
              url = Base64.urlsafe_decode64(encoded_url)

              rss = Html2rss.auto_source(url)
              ttl = (rss.channel.ttl || 60) * 60

              HttpCache.expires(response, ttl, cache_control: 'private, max-age=0, must-revalidate')

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
