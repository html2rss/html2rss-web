# frozen_string_literal: true

require 'date'

module Html2rss
  class AutoSource
    module Scraper
      class Schema
        ##
        # A Thing is kind of the 'base class' for Schema.org schema_objects.
        #
        # @see https://schema.org/Thing
        class Thing
          # Supported Schema.org `@type` values mapped to article extraction.
          SUPPORTED_TYPES = %w[
            AdvertiserContentArticle
            AnalysisNewsArticle
            APIReference
            Article
            AskPublicNewsArticle
            BackgroundNewsArticle
            BlogPosting
            DiscussionForumPosting
            LiveBlogPosting
            NewsArticle
            OpinionNewsArticle
            Report
            ReportageNewsArticle
            ReviewNewsArticle
            SatiricalArticle
            ScholarlyArticle
            SocialMediaPosting
            TechArticle
          ].to_set.freeze

          # Attributes exposed by `#call` in generated article hashes.
          DEFAULT_ATTRIBUTES = %i[id title description url image published_at categories].freeze

          # @param schema_object [Hash{Symbol => Object}] parsed schema.org object
          # @param url [String, Html2rss::Url, nil] base URL used for relative normalization
          def initialize(schema_object, url:)
            @schema_object = schema_object
            @base_url = normalized_base_url(url)
          end

          # @return [Hash] the scraped article hash with DEFAULT_ATTRIBUTES
          def call
            DEFAULT_ATTRIBUTES.to_h do |attribute|
              [attribute, public_send(attribute)]
            end
          end

          # @return [String, nil] stable schema object identifier
          def id
            return @id if defined?(@id)

            id = normalized_id(schema_object[:@id], reference_url: url || base_url) || url&.path.to_s

            return if id.empty?

            @id = id
          end

          # @return [String, nil] article title
          def title = schema_object[:title]

          # @return [String, nil] longest available description field
          def description
            schema_object.values_at(:description, :schema_object_body, :abstract)
                         .max_by { |string| string.to_s.size }
          end

          # @return [Html2rss::Url, nil] the URL of the schema object
          def url
            url = schema_object[:url]
            if url.to_s.empty?
              Log.debug("Schema#Thing.url: no url in schema_object: #{schema_object.inspect}")
              return
            end

            Url.from_relative(url, base_url || url)
          end

          # @return [Html2rss::Url, nil] normalized article image URL
          def image
            if (image_url = image_urls.first)
              Url.from_relative(image_url, base_url || image_url)
            end
          end

          # @return [String, nil] published-at timestamp string
          def published_at = schema_object[:datePublished]

          # @return [Array<String>, nil] extracted category labels
          def categories
            return @categories if defined?(@categories)

            @categories = CategoryExtractor.call(schema_object)
          end

          attr_reader :schema_object, :base_url

          # @return [Array<String>] normalized image URL candidates
          def image_urls
            schema_object.values_at(:image, :thumbnailUrl).filter_map do |object|
              next unless object

              if object.is_a?(String)
                object
              elsif object.is_a?(Hash) && object[:@type] == 'ImageObject'
                object[:url] || object[:contentUrl]
              end
            end
          end

          # @param value [String, Symbol, nil] candidate schema identifier
          # @param reference_url [Html2rss::Url, nil] URL used for same-origin normalization
          # @return [String, nil] normalized identifier value
          def normalized_id(value, reference_url:)
            text = value.to_s
            return if text.empty?

            normalized_url = normalized_id_url(text, reference_url:)
            return text unless reference_url && normalized_url.host == reference_url.host

            normalized_id_value(normalized_url)
          rescue ArgumentError
            text
          end

          # @param text [String] raw identifier text
          # @param reference_url [Html2rss::Url, nil] URL used to resolve relative IDs
          # @return [Html2rss::Url] normalized identifier URL
          def normalized_id_url(text, reference_url:)
            if text.start_with?('/')
              Url.from_relative(text, reference_url || text)
            else
              Url.from_absolute(text)
            end
          end

          # @param url [Html2rss::Url] normalized identifier URL
          # @return [String, nil] path/query portion used as stable ID
          def normalized_id_value(url)
            path = url.path.to_s
            return "#{path}?#{url.query}" if (path.empty? || path == '/') && !url.query.to_s.empty?
            return path unless path.empty?

            url.query
          end

          # @param url [String, Html2rss::Url, nil] candidate page URL
          # @return [Html2rss::Url, nil] normalized absolute URL for schema resolution
          def normalized_base_url(url)
            return if url.to_s.strip.empty?

            Url.from_absolute(url)
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
