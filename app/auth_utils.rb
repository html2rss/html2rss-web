# frozen_string_literal: true

require 'digest'
require 'cgi'

module Html2rss
  module Web
    ##
    # Authentication utility functions
    module AuthUtils
      class << self
        # @param username [String]
        # @param url [String]
        # @param token [String]
        # @return [String] 16-character hex feed ID
        def generate_feed_id(username, url, token)
          content = "#{username}:#{url}:#{token}"
          Digest::SHA256.hexdigest(content)[0..15]
        end

        # Escapes XML special characters to prevent injection attacks
        # @param text [String]
        # @return [String]
        def sanitize_xml(text)
          return '' unless text

          CGI.escapeHTML(text.to_s)
        end
      end
    end
  end
end
