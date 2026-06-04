# frozen_string_literal: true

require 'date'
require 'nokogiri'

module Html2rss
  class AutoSource
    module Scraper
      # Scrapes WordPress sites through their REST API instead of parsing article HTML.
      class WordpressApi # rubocop:disable Metrics/ClassLength
        include Enumerable

        # Selector for WordPress API discovery link tags.
        API_LINK_SELECTOR = 'link[rel="https://api.w.org/"][href]'
        # Selector for canonical link tags used for scope normalization.
        CANONICAL_LINK_SELECTOR = 'link[rel="canonical"][href]'
        # Fields requested from the WordPress posts endpoint.
        POSTS_FIELDS = %w[id title excerpt content link date categories].freeze
        # Baseline query sent to WordPress posts API follow-ups.
        POSTS_QUERY_DEFAULTS = {
          '_fields' => POSTS_FIELDS.join(','),
          'per_page' => '100'
        }.freeze
        # @return [Symbol] scraper config key
        def self.options_key = :wordpress_api

        ##
        # @param parsed_body [Nokogiri::HTML::Document, nil] parsed HTML document
        # @return [Boolean] whether the page advertises a WordPress REST API endpoint
        def self.articles?(parsed_body)
          return false unless parsed_body

          !parsed_body.at_css(API_LINK_SELECTOR).nil?
        end

        ##
        # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
        # @param url [String, Html2rss::Url] canonical page URL
        # @param request_session [Html2rss::RequestSession, nil] shared request session for follow-up fetches
        # @param _opts [Hash] unused scraper-specific options
        # @option _opts [Object] :_reserved reserved for future scraper-specific options
        # @return [void]
        def initialize(parsed_body, url:, request_session: nil, **_opts)
          @parsed_body = parsed_body
          @url = Html2rss::Url.from_absolute(url)
          @request_session = request_session
          @page_scope = PageScope.from(parsed_body:, url: @url)
        end

        ##
        # Yields article hashes from the WordPress posts API.
        #
        # @yieldparam article [Hash{Symbol => Object}] normalized article hash
        # @return [Enumerator, void] enumerator when no block is given
        def each
          return enum_for(:each) unless block_given?
          return unless (posts = fetch_posts)

          posts.filter_map { article_from(_1) }.each { yield(_1) }
        end

        private

        attr_reader :parsed_body, :url, :request_session, :page_scope

        def fetch_posts
          response = posts_response
          return unless response

          Array(response.parsed_body)
        rescue RequestService::UnsupportedResponseContentType => error
          Log.warn("#{self.class}: unsupported WordPress API posts content type (#{error.message})")
          nil
        rescue JSON::ParserError => error
          Log.warn("#{self.class}: failed to parse WordPress API posts JSON (#{error.message})")
          nil
        end

        def posts_response
          return unless request_session
          return unless (resolved_posts_url = posts_endpoint_url)

          request_session.follow_up(
            url: resolved_posts_url,
            relation: :auto_source,
            origin_url: url
          )
        rescue Html2rss::Error => error
          Log.warn("#{self.class}: failed to fetch WordPress API posts (#{error.class}: #{error.message})")
          nil
        end

        def article_from(post)
          return unless post.is_a?(Hash)

          article_url = article_url(post)
          return unless article_url

          article_attributes(post, article_url).compact
        end

        def article_url(post)
          absolute_link(post[:link])
        end

        def article_id(_post, article_url)
          root_path_query_id(article_url) || present_string(article_url.path) || article_url.to_s
        end

        def article_title(post)
          rendered_text(post.dig(:title, :rendered))
        end

        def article_description(post)
          rendered_html(post.dig(:content, :rendered)) || rendered_html(post.dig(:excerpt, :rendered))
        end

        def article_published_at(post)
          present_string(post[:date])
        end

        def article_categories(post)
          Array(post[:categories]).filter_map { |value| present_string(value) }
        end

        def article_attributes(post, article_url)
          {
            id: article_id(post, article_url),
            title: article_title(post),
            description: article_description(post),
            url: article_url,
            published_at: article_published_at(post),
            categories: article_categories(post)
          }
        end

        def absolute_link(link)
          value = present_string(link)
          return unless value

          Html2rss::Url.from_relative(value, url)
        rescue ArgumentError
          nil
        end

        def rendered_text(value)
          rendered_html(value)&.then { Nokogiri::HTML.fragment(_1).text.strip }
        end

        def rendered_html(value)
          text = present_string(value)
          text unless text.nil?
        end

        def present_string(value)
          text = value.to_s.strip
          text unless text.empty?
        end

        def root_path_query_id(article_url)
          query = present_string(article_url.query)
          return unless query

          path = article_url.path.to_s
          return unless path.empty? || path == '/'

          "/?#{query}"
        end

        def posts_query
          POSTS_QUERY_DEFAULTS.merge(page_scope.query).transform_values(&:to_s)
        end

        def posts_endpoint_url
          PostsEndpoint.resolve(
            parsed_body:,
            page_url: url,
            page_scope:,
            posts_query:,
            logger: Log
          )
        end
      end
    end
  end
end
