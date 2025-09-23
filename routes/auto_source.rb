# frozen_string_literal: true

require 'json'
require 'base64'
require 'uri'
require_relative '../app/auto_source'
require_relative '../app/auth'

module Html2rss
  module Web
    module AutoSourceRoutes
      module_function

      def handle_auto_source_routes(router)
        unless AutoSource.enabled?
          router.response.status = 400
          return 'Auto source feature is disabled'
        end

        router.on 'create' do
          handle_create_feed(router)
        end

        router.on String do |encoded_url|
          handle_legacy_feed(router, encoded_url)
        end
      end

      def handle_create_feed(router)
        unless router.request_method == 'POST'
          router.response.status = 405
          return 'Method Not Allowed'
        end

        account = Auth.authenticate(router)
        unless account
          router.response.status = 401
          return 'Unauthorized'
        end

        url = router.params['url']
        unless url && Auth.valid_url?(url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless Auth.url_allowed?(account, url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        feed_data = AutoSource.create_stable_feed('Generated Feed', url, account, strategy)
        unless feed_data
          router.response.status = 500
          return 'Internal Server Error'
        end

        router.response['Content-Type'] = 'application/json'
        JSON.generate(feed_data)
      end

      def handle_stable_feed(router, feed_id)
        feed_token = router.params['token']

        if feed_token
          handle_public_feed(router, feed_id, feed_token)
        else
          handle_authenticated_feed(router)
        end
      end

      def handle_legacy_feed(router, encoded_url)
        account = Auth.authenticate(router)
        unless account
          router.response.status = 401
          return 'Unauthorized'
        end

        unless AutoSource.allowed_origin?(router)
          router.response.status = 403
          return 'Forbidden'
        end

        decoded_url = Base64.urlsafe_decode64(encoded_url)
        unless decoded_url && Auth.valid_url?(decoded_url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless AutoSource.url_allowed_for_token?(account, decoded_url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed(encoded_url, strategy)

        router.response['Content-Type'] = 'application/xml'
        rss_content.to_s
      rescue ArgumentError
        router.response.status = 400
        'Bad Request'
      end

      def handle_public_feed(router, _feed_id, feed_token)
        url = router.params['url']
        unless url && Auth.valid_url?(url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless Auth.feed_url_allowed?(feed_token, url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        router.response['Content-Type'] = 'application/xml'
        rss_content.to_s
      end

      def handle_authenticated_feed(router)
        account = Auth.authenticate(router)
        unless account
          router.response.status = 401
          return 'Unauthorized'
        end

        url = router.params['url']
        unless url && Auth.valid_url?(url)
          router.response.status = 400
          return 'Bad Request'
        end

        unless Auth.url_allowed?(account, url)
          router.response.status = 403
          return 'Forbidden'
        end

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        router.response['Content-Type'] = 'application/xml'
        rss_content.to_s
      end
    end
  end
end
