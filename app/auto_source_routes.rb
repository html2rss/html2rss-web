# frozen_string_literal: true

require 'json'
require 'base64'
require_relative 'auto_source'
require_relative 'auth'
require_relative 'xml_builder'

module Html2rss
  module Web
    ##
    # Auto source routes for the html2rss-web application
    module AutoSourceRoutes
      module_function

      ##
      # Handle the auto_source hash branch routing
      # @param router [Roda::Roda] The Roda router instance
      def handle_auto_source_routes(router)
        return auto_source_disabled_response(router) unless AutoSource.enabled?

        # New stable feed creation and management
        router.on 'create' do
          handle_create_feed(router)
        end

        router.on 'feeds' do
          handle_list_feeds(router)
        end

        # Legacy encoded URL route (for backward compatibility)
        router.on String do |encoded_url|
          handle_legacy_auto_source_feed(router, encoded_url)
        end
      end

      ##
      # Handle stable feed access (both public and authenticated)
      # @param router [Roda::Roda] The Roda router instance
      # @param feed_id [String] The feed ID
      def handle_stable_feed(router, feed_id)
        url = router.params['url']
        feed_token = router.params['token']

        return bad_request_response(router, 'URL parameter required') unless url
        return bad_request_response(router, 'URL too long') if url.length > 2048
        return bad_request_response(router, 'Invalid URL format') unless Auth.valid_url?(url)

        return handle_public_feed_access(router, feed_id, feed_token, url) if feed_token

        handle_authenticated_feed_access(router, url)
      rescue StandardError => error
        handle_auto_source_error(router, error)
      end

      def handle_public_feed_access(router, _feed_id, feed_token, url)
        # Validate feed token and URL
        return access_denied_response(router, url) unless Auth.feed_url_allowed?(feed_token, url)

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        configure_auto_source_headers(router)
        rss_content.to_s
      rescue StandardError => error
        handle_auto_source_error(router, error)
      end

      def handle_authenticated_feed_access(router, url)
        token_data = Auth.authenticate(router)
        return unauthorized_response(router) unless token_data

        return access_denied_response(router, url) unless AutoSource.url_allowed_for_token?(token_data, url)

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed_content(url, strategy)

        configure_auto_source_headers(router)
        rss_content.to_s
      end

      def handle_auto_source_error(router, error)
        router.response.status = 500
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: error.message)
      end

      # Helper methods that need to be implemented by the main app
      def bad_request_response(router, message)
        router.response.status = 400
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_access_denied_feed(message)
      end

      def unauthorized_response(router)
        router.response.status = 401
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Unauthorized')
      end

      def access_denied_response(router, url)
        router.response.status = 403
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_access_denied_feed(url)
      end

      def method_not_allowed_response(router)
        router.response.status = 405
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Method Not Allowed')
      end

      def internal_error_response(router)
        router.response.status = 500
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Internal Server Error')
      end

      def forbidden_origin_response(router)
        router.response.status = 403
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'Forbidden Origin')
      end

      def configure_auto_source_headers(router)
        router.response['Content-Type'] = 'application/xml'
        router.response['Cache-Control'] = 'public, max-age=3600'
        router.response['X-Content-Type-Options'] = 'nosniff'
        router.response['X-XSS-Protection'] = '1; mode=block'
      end

      def validate_and_decode_base64(encoded_url)
        Base64.urlsafe_decode64(encoded_url)
      rescue ArgumentError
        nil
      end

      private

      def auto_source_disabled_response(router)
        router.response.status = 400
        router.response['Content-Type'] = 'application/xml'
        XmlBuilder.build_error_feed(message: 'The auto source feature is disabled.', title: 'Auto Source Disabled')
      end

      def handle_create_feed(router)
        return method_not_allowed_response(router) unless router.post?

        token_data = Auth.authenticate(router)
        return unauthorized_response(router) unless token_data

        url = router.params['url']
        return bad_request_response(router, 'URL parameter required') unless url

        return access_denied_response(router, url) unless AutoSource.url_allowed_for_token?(token_data, url)

        create_feed_response(router, url, token_data, router.params)
      rescue StandardError => error
        handle_auto_source_error(router, error)
      end

      def create_feed_response(router, url, token_data, params)
        name = params['name'] || "Auto-generated feed for #{url}"
        strategy = params['strategy'] || 'ssrf_filter'

        feed_data = AutoSource.create_stable_feed(name, url, token_data, strategy)
        return internal_error_response(router) unless feed_data

        router.response['Content-Type'] = 'application/json'
        JSON.generate(feed_data)
      end

      def handle_list_feeds(router)
        token_data = Auth.authenticate(router)
        return unauthorized_response(router) unless token_data

        # For stateless system, we can't list feeds without storage
        # Return empty array for now
        router.response['Content-Type'] = 'application/json'
        JSON.generate([])
      end

      def handle_legacy_auto_source_feed(router, encoded_url)
        token_data = AutoSource.authenticate_with_token(router)
        return unauthorized_response(router) unless token_data
        return forbidden_origin_response(router) unless AutoSource.allowed_origin?(router)

        process_legacy_auto_source_request(router, encoded_url, token_data)
      rescue StandardError => error
        handle_auto_source_error(router, error)
      end

      def process_legacy_auto_source_request(router, encoded_url, token_data)
        decoded_url = validate_and_decode_base64(encoded_url)
        return bad_request_response(router, 'Invalid URL encoding') unless decoded_url
        return bad_request_response(router, 'Invalid URL format') unless Auth.valid_url?(decoded_url)
        return access_denied_response(router, decoded_url) unless AutoSource.url_allowed_for_token?(token_data,
                                                                                                    decoded_url)

        strategy = router.params['strategy'] || 'ssrf_filter'
        rss_content = AutoSource.generate_feed(encoded_url, strategy)
        configure_auto_source_headers(router)
        rss_content.to_s
      end
    end
  end
end
