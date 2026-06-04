# frozen_string_literal: true

module Html2rss
  class AutoSource
    module Scraper
      class WordpressApi
        ##
        # Resolves the WordPress posts endpoint for a given page and scope.
        class PostsEndpoint
          # REST API collection path for posts resources.
          POSTS_PATH = 'wp/v2/posts'

          ##
          # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
          # @param page_url [Html2rss::Url] canonical page URL
          # @param page_scope [Html2rss::AutoSource::Scraper::WordpressApi::PageScope] derived page scope
          # @param posts_query [Hash{String => String}] query params for the posts request
          # @param logger [Logger] logger used for operational warnings
          # @return [Html2rss::Url, nil] resolved posts endpoint or nil when unavailable
          def self.resolve(parsed_body:, page_url:, page_scope:, posts_query:, logger: Html2rss::Log)
            new(parsed_body:, page_url:, page_scope:, posts_query:, logger:).call
          end

          ##
          # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
          # @param page_url [Html2rss::Url] canonical page URL
          # @param page_scope [Html2rss::AutoSource::Scraper::WordpressApi::PageScope] derived page scope
          # @param posts_query [Hash{String => String}] query params for the posts request
          # @param logger [Logger] logger used for operational warnings
          def initialize(parsed_body:, page_url:, page_scope:, posts_query:, logger:)
            @parsed_body = parsed_body
            @page_url = Html2rss::Url.from_absolute(page_url)
            @page_scope = page_scope
            @posts_query = posts_query
            @logger = logger
          end

          ##
          # @return [Html2rss::Url, nil] resolved posts endpoint or nil when unavailable
          def call
            api_root = api_root_url
            return unless api_root
            return unless fetchable_page_scope?

            query_style_api_root?(api_root) ? query_root_posts_url(api_root) : posts_collection_url(api_root)
          end

          private

          attr_reader :parsed_body, :page_url, :page_scope, :posts_query, :logger

          def api_root_url
            href = parsed_body.at_css(WordpressApi::API_LINK_SELECTOR)&.[]('href').to_s.strip
            return log_missing_api_root if href.empty?

            Html2rss::Url.from_relative(href, page_url)
          rescue Addressable::URI::InvalidURIError, ArgumentError => error
            logger.warn("#{WordpressApi}: invalid WordPress API endpoint #{href.inspect} (#{error.message})")
            nil
          end

          def fetchable_page_scope?
            return true if page_scope.fetchable?

            if page_scope.reason == :non_archive
              logger.debug(
                "#{WordpressApi}: page advertised WordPress API support " \
                'without a safe WordPress archive scope'
              )
              return false
            end

            logger.warn("#{WordpressApi}: unable to derive safe WordPress archive scope for #{page_url}")
            false
          end

          def log_missing_api_root
            logger.debug("#{WordpressApi}: page advertised WordPress API support without a usable API root")
            nil
          end

          def query_style_api_root?(api_root)
            api_root.query_values.key?('rest_route')
          end

          def query_root_posts_url(api_root)
            query = api_root.query_values
            route = normalized_rest_route(query.fetch('rest_route', '/'))
            api_root.with_query_values(
              query.merge(
                'rest_route' => append_posts_route(route),
                **posts_query
              )
            )
          end

          def posts_collection_url(api_root)
            Html2rss::Url.from_relative(POSTS_PATH, normalized_api_root(api_root))
                         .with_query_values(api_root.query_values.merge(posts_query))
          end

          def normalized_api_root(api_root)
            api_root.with_path(normalized_api_path(api_root.path))
          end

          def normalized_api_path(path)
            segments = path.to_s.split('/').reject(&:empty?)
            normalized_path = "/#{segments.join('/')}"
            normalized_path = '/' if normalized_path == '/'
            normalized_path.end_with?('/') ? normalized_path : "#{normalized_path}/"
          end

          def normalized_rest_route(route)
            value = route.to_s
            value = '/' if value.empty?
            value = "/#{value}" unless value.start_with?('/')
            trim_trailing_slashes(value)
          end

          def trim_trailing_slashes(value)
            end_index = value.length
            end_index -= 1 while end_index > 1 && value.getbyte(end_index - 1) == 47
            value[0, end_index]
          end

          def append_posts_route(route)
            return '/wp/v2/posts' if route == '/'

            "#{route}/wp/v2/posts"
          end
        end
      end
    end
  end
end
