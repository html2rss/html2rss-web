# frozen_string_literal: true

module Html2rss
  class AutoSource
    module Scraper
      class WordpressApi
        ##
        # Determines whether a WordPress page can safely be mapped to a posts query.
        class PageScope
          # Canonical path segment for category archives.
          CATEGORY_SEGMENT = 'category'
          # Canonical path segment for tag archives.
          TAG_SEGMENT = 'tag'
          # Canonical path segment for author archives.
          AUTHOR_SEGMENT = 'author'
          # Canonical path segment for paginated archives.
          PAGE_SEGMENT = 'page'
          # Canonical query key used for paginated archives.
          PAGED_QUERY_KEY = 'paged'

          ##
          # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
          # @param url [Html2rss::Url] canonical page URL
          # @return [PageScope] derived page scope
          def self.from(parsed_body:, url:)
            Resolver.new(parsed_body:, url:).call
          end

          ##
          # @param query [Hash{String => String}] scoped query params for the posts endpoint
          # @param fetchable [Boolean] whether a posts follow-up is safe for this page
          # @param reason [Symbol] classification of the resolved page scope
          def initialize(query:, fetchable:, reason:)
            @query = query.freeze
            @fetchable = fetchable
            @reason = reason
            freeze
          end

          ##
          # @return [Hash{String => String}] query params to apply to the posts request
          attr_reader :query

          ##
          # @return [Boolean] whether the page may safely use the posts API follow-up
          def fetchable?
            @fetchable
          end

          ##
          # @return [Symbol] classification of the resolved page scope
          attr_reader :reason

          ##
          # Resolves the page scope from page markup and canonical URL signals.
          class Resolver # rubocop:disable Metrics/ClassLength
            ##
            # @param parsed_body [Nokogiri::HTML::Document] parsed HTML document
            # @param url [Html2rss::Url] canonical page URL
            def initialize(parsed_body:, url:)
              @parsed_body = parsed_body
              @url = Html2rss::Url.from_absolute(url)
            end

            ##
            # @return [PageScope] derived page scope
            def call
              scope = category_scope ||
                      tag_scope ||
                      author_scope ||
                      date_scope ||
                      fallback_scope

              apply_pagination(scope)
            end

            private

            attr_reader :parsed_body, :url

            def category_scope
              return unless category_archive?

              scoped_scope('categories' => archive_id('category'))
            end

            def tag_scope
              return unless tag_archive?

              scoped_scope('tags' => archive_id('tag'))
            end

            def author_scope
              return unless author_archive?

              scoped_scope('author' => archive_id('author'))
            end

            def date_scope
              return unless date_archive?

              range = date_archive_range
              return unknown_archive_scope unless range

              PageScope.new(query: range, fetchable: true, reason: :archive)
            end

            def fallback_scope
              return unknown_archive_scope if archive_like?
              return non_archive_scope if singular_like?

              PageScope.new(query: {}, fetchable: true, reason: :unscoped)
            end

            def apply_pagination(scope)
              page = archive_page_number
              return scope unless scope.fetchable? && page

              PageScope.new(
                query: scope.query.merge('page' => page.to_s),
                fetchable: scope.fetchable?,
                reason: scope.reason
              )
            end

            def scoped_scope(query)
              return unknown_archive_scope if query.values.any?(&:nil?)

              PageScope.new(query:, fetchable: true, reason: :archive)
            end

            def unknown_archive_scope
              PageScope.new(query: {}, fetchable: false, reason: :unsupported_archive)
            end

            def non_archive_scope
              PageScope.new(query: {}, fetchable: false, reason: :non_archive)
            end

            def category_archive?
              body_classes.include?('category') || leading_path_segment == CATEGORY_SEGMENT
            end

            def tag_archive?
              body_classes.include?('tag') || leading_path_segment == TAG_SEGMENT
            end

            def author_archive?
              body_classes.include?('author') || leading_path_segment == AUTHOR_SEGMENT
            end

            def date_archive?
              body_classes.include?('date') || date_archive_path?
            end

            def archive_like?
              category_archive? || tag_archive? || author_archive? || date_archive? || body_classes.include?('archive')
            end

            def singular_like?
              body_classes.intersect?(%w[page single singular attachment]) ||
                body_classes.any? { _1.match?(/\A(?:page-id|postid)-\d+\z/) }
            end

            def body_classes
              @body_classes ||= parsed_body.at_css('body')&.[]('class').to_s.split
            end

            def archive_id(prefix)
              body_classes.filter_map do |klass|
                klass[Regexp.new("^#{Regexp.escape(prefix)}-(\\d+)$"), 1]
              end.first
            end

            def canonical_or_current_url
              href = parsed_body.at_css(WordpressApi::CANONICAL_LINK_SELECTOR)&.[]('href').to_s.strip
              return url if href.empty?

              canonical_url = Html2rss::Url.from_relative(href, url)
              same_origin_url?(canonical_url, url) ? canonical_url : url
            rescue ArgumentError
              url
            end

            def path_segments
              @path_segments ||= canonical_or_current_url.path_segments
            end

            def scoped_path_segments
              @scoped_path_segments ||= paginated_path? ? path_segments[0...-2] : path_segments
            end

            def leading_path_segment
              scoped_path_segments.first
            end

            def date_archive_path?
              !date_archive_segments.nil?
            end

            def date_archive_range
              components = date_archive_components
              return unless components

              start_date = Date.new(*components.fetch(:start_date_parts))
              {
                'after' => iso8601_start(start_date),
                'before' => iso8601_start(next_archive_boundary(start_date, components.fetch(:precision)))
              }
            rescue Date::Error
              nil
            end

            def date_archive_components
              segments = date_archive_segments
              return unless segments

              year = segments.fetch(0).to_i
              month = parse_archive_segment(segments[1], 1, 12)
              day = parse_archive_segment(segments[2], 1, 31)

              {
                start_date_parts: [year, month || 1, day || 1],
                precision: archive_precision(month:, day:)
              }
            end

            def date_archive_segments
              year_index = scoped_path_segments.find_index { _1.match?(/\A\d{4}\z/) }
              return unless year_index

              segments = scoped_path_segments.drop(year_index)
              return unless segments.length.between?(1, 3)
              return unless archive_segment_shape?(segments)

              segments
            end

            def paginated_path?
              return false if path_segments.length < 2
              return false unless path_segments[-2] == PAGE_SEGMENT

              !parse_positive_integer(path_segments[-1]).nil?
            end

            def archive_page_number
              parse_positive_integer(canonical_or_current_url.query_values[PAGED_QUERY_KEY]) || path_page_number
            end

            def path_page_number
              return unless paginated_path?

              parse_positive_integer(path_segments[-1])
            end

            def archive_segment_shape?(segments)
              month = segments[1]
              day = segments[2]
              return false if day && month.nil?
              return false unless month.nil? || month.match?(/\A\d+\z/)
              return false unless day.nil? || day.match?(/\A\d+\z/)

              true
            end

            def same_origin_url?(left, right)
              [left.scheme, left.host, left.port] == [right.scheme, right.host, right.port]
            end

            def archive_precision(month:, day:)
              return :day if day
              return :month if month

              :year
            end

            def next_archive_boundary(start_date, precision)
              {
                year: start_date.next_year,
                month: start_date.next_month,
                day: start_date.next_day
              }.fetch(precision)
            end

            def iso8601_start(date)
              date.strftime('%Y-%m-%dT00:00:00Z')
            end

            def parse_archive_segment(value, minimum, maximum)
              return nil unless value&.match?(/\A\d+\z/)

              number = value.to_i
              return nil if number < minimum || number > maximum

              number
            end

            def parse_positive_integer(value)
              return nil unless value.to_s.match?(/\A\d+\z/)

              number = value.to_i
              return nil if number < 1

              number
            end
          end
        end
      end
    end
  end
end
