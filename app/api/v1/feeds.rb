# frozen_string_literal: true

require_relative 'contract'
require_relative 'feeds/create_feed'
require_relative 'feeds/show_feed'

module Html2rss
  module Web
    module Api
      module V1
        module Feeds
          class << self
            def show(request, token)
              ShowFeed.call(request, token)
            end

            def create(request)
              CreateFeed.call(request)
            end

            # Compatibility seam for existing tests and callers.
            def extract_site_title(url)
              CreateFeed.extract_site_title(url)
            end
          end
        end
      end
    end
  end
end
