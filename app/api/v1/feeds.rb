# frozen_string_literal: true

require 'html2rss/url'

require_relative 'contract'
require_relative 'feeds/create_feed'
require_relative 'feeds/show_feed'

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Thin entrypoint for feed API actions.
        #
        # This indirection keeps route files small while exposing one stable
        # namespace for create/show operations.
        module Feeds
          class << self
            # @param request [Rack::Request]
            # @param token [String]
            # @return [String] serialized feed body.
            def show(request, token)
              ShowFeed.call(request, token)
            end

            # @param request [Rack::Request]
            # @return [Hash{Symbol=>Object}] JSON-ready API payload.
            def create(request)
              CreateFeed.call(request)
            end

            # Compatibility seam for existing tests and callers.
            #
            # @param url [String]
            # @return [String, nil]
            def extract_site_title(url)
              Html2rss::Url.for_channel(url).channel_titleized
            rescue StandardError
              nil
            end
          end
        end
      end
    end
  end
end
