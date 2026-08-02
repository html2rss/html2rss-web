# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Immutable feed-token value object.
    #
    # Wire encoding lives in {FeedToken::Codec}; HMAC creation and checks live
    # in {FeedToken::Signer}.
    FeedToken = Data.define(:username, :url, :expires_at, :signature, :strategy) do
      # @return [Boolean]
      def expired?
        Time.now.to_i > expires_at
      end

      # @param candidate_url [String]
      # @return [Boolean]
      def valid_for_url?(candidate_url)
        url == candidate_url
      end
    end

    FeedToken::DEFAULT_EXPIRY = 315_360_000
  end
end
