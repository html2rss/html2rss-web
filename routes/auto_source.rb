# frozen_string_literal: true

require 'json'
require 'base64'
require_relative '../app/auto_source'
require_relative '../app/base_route_handler'

module Html2rss
  module Web
    ##
    # Auto source routes for the html2rss-web application
    # Now uses BaseRouteHandler to eliminate repetitive patterns
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
        context = BaseRouteHandler.create_context(router)
        feed_token = context.params['token']

        if feed_token
          handle_public_feed_access(context, feed_id, feed_token)
        else
          handle_authenticated_feed_access(context)
        end
      end

      def handle_public_feed_access(context, _feed_id, feed_token)
        BaseRouteHandler.with_url_validation(context) do |url|
          return context.response_context.access_denied_response(url) unless Auth.feed_url_allowed?(feed_token, url)

          rss_content = AutoSource.generate_feed_content(url, context.strategy)
          BaseRouteHandler.public_feed_response(context, rss_content)
        end
      end

      def handle_authenticated_feed_access(context)
        BaseRouteHandler.with_full_validation(context) do |_account, url|
          rss_content = AutoSource.generate_feed_content(url, context.strategy)
          BaseRouteHandler.auto_source_response(context, rss_content)
        end
      end

      def handle_create_feed(router)
        context = BaseRouteHandler.create_context(router)

        BaseRouteHandler.with_method_validation(context, 'POST') do |ctx|
          BaseRouteHandler.with_full_validation(ctx) do |account, url|
            name = ctx.name(url)
            feed_data = AutoSource.create_stable_feed(name, url, account, ctx.strategy)

            return context.response_context.internal_error_response unless feed_data

            BaseRouteHandler.json_response(context, feed_data)
          end
        end
      end

      def handle_list_feeds(router)
        context = BaseRouteHandler.create_context(router)

        BaseRouteHandler.with_auth(context) do |_account|
          # For stateless system, we can't list feeds without storage
          # Return empty array for now
          BaseRouteHandler.json_response(context, [])
        end
      end

      def handle_legacy_auto_source_feed(router, encoded_url)
        context = BaseRouteHandler.create_context(router)

        BaseRouteHandler.with_auth(context) do |account|
          return nil unless AutoSource.allowed_origin?(router)

          validation_result = validate_legacy_feed_url(context, encoded_url, account)
          return validation_result if validation_result

          rss_content = AutoSource.generate_feed(encoded_url, context.strategy)
          BaseRouteHandler.auto_source_response(context, rss_content)
        end
      end

      private

      def auto_source_disabled_response(router)
        context = BaseRouteHandler.create_context(router)
        context.response_context.bad_request_response('The auto source feature is disabled.')
      end

      def validate_legacy_feed_url(context, encoded_url, account)
        decoded_url = validate_and_decode_base64(encoded_url)
        return context.response_context.bad_request_response('Invalid URL encoding') unless decoded_url
        return context.response_context.bad_request_response('Invalid URL format') unless Auth.valid_url?(decoded_url)
        return context.response_context.access_denied_response(decoded_url) unless AutoSource.url_allowed_for_token?(
          account, decoded_url
        )

        nil
      end

      def validate_and_decode_base64(encoded_url)
        Base64.urlsafe_decode64(encoded_url)
      rescue ArgumentError
        nil
      end
    end
  end
end
