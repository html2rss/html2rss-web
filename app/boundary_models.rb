# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Immutable boundary contracts for high-churn API/service handoffs.
    module BoundaryModels
      ##
      # Feed create parameters contract.
      FeedCreateParams = Data.define(:url, :name, :strategy) do
        # @return [Hash{Symbol=>Object}]
        def to_h
          { url: url, name: name, strategy: strategy }
        end
      end

      ##
      # Feed metadata contract used between feed services and API responses.
      FeedMetadata = Data.define(:id, :name, :url, :username, :strategy, :public_url) do
        # @return [Hash{Symbol=>Object}]
        def to_h
          {
            id: id,
            name: name,
            url: url,
            username: username,
            strategy: strategy,
            public_url: public_url
          }
        end
      end
    end
  end
end
