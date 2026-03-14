# frozen_string_literal: true

require_relative 'feed_identity'
require_relative '../security/auth'
require_relative '../security/feed_access'

module Html2rss
  module Web
    ##
    # Stateless helpers for auto-source feed creation and rendering.
    #
    # Responsibilities stay small: validate access, create stable identifiers,
    # and delegate actual scraping/rendering to feed services.
    module AutoSource
      class << self
        # @return [Boolean]
        def enabled?
          EnvironmentValidator.auto_source_enabled?
        end

        # Builds stable feed metadata for an authenticated account.
        #
        # @param name [String, nil]
        # @param url [String]
        # @param token_data [Hash{Symbol=>Object}] authenticated account data.
        # @param strategy [String]
        # @return [Html2rss::Web::FeedContracts::Metadata, nil]
        def create_stable_feed(name, url, token_data, strategy = 'ssrf_filter')
          return nil unless token_data && FeedAccess.url_allowed_for_username?(token_data[:username], url)

          feed_token = Auth.generate_feed_token(token_data[:username], url, strategy: strategy)
          return nil unless feed_token

          FeedIdentity.metadata(metadata_attributes(name, url, token_data, strategy, feed_token))
        end

        private

        # @param name [String, nil]
        # @param url [String]
        # @param token_data [Hash{Symbol=>Object}]
        # @param strategy [String]
        # @param feed_token [String]
        # @return [Hash{Symbol=>Object}]
        def metadata_attributes(name, url, token_data, strategy, feed_token)
          {
            name: name,
            url: url,
            username: token_data[:username],
            strategy: strategy,
            feed_token: feed_token,
            identity_token: token_data[:token]
          }
        end
      end
    end
  end
end
