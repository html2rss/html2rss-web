# frozen_string_literal: true

require_relative '../app/http_cache'
require_relative '../helpers/auto_source'

module Html2rss
  module Web
    class App
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
              rss = AutoSource.build_auto_source_from_encoded_url(encoded_url)

              HttpCache.expires response,
                                AutoSource.ttl_in_seconds(rss),
                                cache_control: 'private, must-revalidate'

              response['Content-Type'] = CONTENT_TYPE_RSS

              rss.to_s
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
    end
  end
end
