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
              unless Html2rss::RequestService.strategy_registered?(strategy)
                raise Html2rss::RequestService::UnknownStrategy
              end

              response['Content-Type'] = CONTENT_TYPE_RSS

              url = Addressable::URI.parse Base64.urlsafe_decode64(encoded_url)
              rss = Html2rss.auto_source(url, strategy:)

              # Unfortunately, Ruby's rss gem does not provide a direct method to
              # add an XML stylesheet to the RSS::RSS object itself.
              stylesheet = Html2rss::RssBuilder::Stylesheet.new(href: '/rss.xsl', type: 'text/xsl').to_xml

              xml_content = rss.to_xml
              xml_content.sub!(/^<\?xml version="1.0" encoding="UTF-8"\?>/,
                               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n#{stylesheet}")

              HttpCache.expires response,
                                AutoSource.ttl_in_seconds(rss),
                                cache_control: 'private, must-revalidate'

              xml_content
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
