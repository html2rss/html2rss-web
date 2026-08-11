# frozen_string_literal: true

require 'rss'
require 'json'
require 'time'

module Html2rss
  module Web
    module Feeds
      ##
      # rubocop:disable Metrics/ModuleLength, Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
      module Renderer
        JSON_FEED_VERSION = 'https://jsonfeed.org/version/1.1'

        EMPTY_FEED_DESCRIPTION_TEMPLATE = <<~DESC
          We could not extract entries from %<url>s right now.
          The source may block automated requests, require dynamic rendering, or be temporarily unavailable.
        DESC

        EMPTY_FEED_ITEM_TEMPLATE = <<~DESC
          No entries were extracted from %<url>s.

          What you can do:
          - Try again in a few moments
          - Open the original page to confirm content is available
          - Reach out to the site owner if access is restricted
        DESC

        JSON_FEED = :json_feed
        RSS = :rss

        JSON_CONTENT_TYPE = 'application/feed+json'
        RSS_CONTENT_TYPE = 'application/xml'

        PATH_FORMATS = {
          '.json' => JSON_FEED,
          '.rss' => RSS,
          '.xml' => RSS
        }.freeze

        JSON_MEDIA_TYPES = [
          'application/feed+json',
          'application/json'
        ].freeze

        RSS_MEDIA_TYPES = [
          'application/rss+xml',
          'application/xml',
          'text/xml'
        ].freeze

        MediaRange = Data.define(:type, :subtype, :quality, :position) do
          # @return [Integer]
          def specificity
            return 0 if type == '*' && subtype == '*'
            return 1 if subtype == '*'

            2
          end

          # @param candidate [String]
          # @return [Boolean]
          def matches?(candidate)
            candidate_type, candidate_subtype = candidate.downcase.split('/', 2)
            return true if type == '*' && subtype == '*'
            return candidate_type == type if subtype == '*'

            candidate_type == type && candidate_subtype == subtype
          end
        end

        class << self
          # Renders a RenderResult and configures the HTTP response headers and status.
          #
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param response [Rack::Response]
          # @param request [Rack::Request]
          # @return [String] serialized feed representation
          def render(result, response:, request:)
            format = for_request(request)

            response.status = status_for(result.status)
            response['Content-Type'] = content_type(format)
            apply_cache_headers(response, result)
            ::Html2rss::Web::HttpCache.vary(response, 'Accept')

            call(result, format: format)
          end

          # Renders an error feed and configures the HTTP response headers and status.
          #
          # @param message [String] the error message to display in the feed.
          # @param response [Rack::Response] the Rack response.
          # @param request [Rack::Request] the Rack request.
          # @param format [Symbol, nil] explicit format (:rss or :json_feed), or nil to negotiate.
          # @return [String] serialized error feed representation
          def render_error(message, response:, request:, format: nil)
            resolved_format = format || for_request(request)

            response['Content-Type'] = content_type(resolved_format)
            ::Html2rss::Web::HttpCache.expires_now(response)

            call_error(message: message, format: resolved_format)
          end

          # Renders a RenderResult into the requested format.
          #
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param format [Symbol] :rss or :json_feed
          # @return [String] serialized feed representation
          def call(result, format:)
            case result.status
            when :ok
              render_success(result, format)
            when :empty
              render_empty(result, format)
            else
              call_error(message: result.message || HttpError::DEFAULT_MESSAGE, format: format)
            end
          end

          # Renders a single-item error feed in the requested format.
          #
          # @param message [String] the error message to display in the feed.
          # @param format [Symbol] :rss or :json_feed
          # @return [String] serialized error feed representation
          def call_error(message:, format:)
            title = 'Error'
            desc = "Failed to generate feed: #{message}"
            timestamp = Time.now.utc

            if format == JSON_FEED
              JSON.generate({
                              version: JSON_FEED_VERSION,
                              title: title,
                              description: desc,
                              items: [{
                                id: "#{title}-#{timestamp.iso8601}",
                                title: title,
                                content_text: message,
                                date_published: timestamp.iso8601
                              }]
                            })
            else
              build_rss(
                title: title,
                description: desc,
                items: [{
                  title: title,
                  description: message,
                  pubDate: timestamp
                }],
                timestamp: timestamp
              )
            end
          end

          # @param request [Rack::Request]
          # @return [Symbol] negotiated feed format.
          def for_request(request)
            from_path(request_path(request)) || from_accept(accept_header(request)) || RSS
          end

          # @param path [String]
          # @return [Symbol, nil] format implied by known extension.
          def from_path(path)
            PATH_FORMATS.each do |suffix, format|
              return format if path.end_with?(suffix)
            end

            nil
          end

          # @param value [String]
          # @return [String] input without a known feed extension suffix.
          def strip_known_extension(value)
            string = value.to_s

            PATH_FORMATS.each_key do |suffix|
              return string.delete_suffix(suffix) if string.end_with?(suffix)
            end

            string
          end

          # @param format [Symbol]
          # @return [String] HTTP content type for the negotiated format.
          def content_type(format)
            format == JSON_FEED ? JSON_CONTENT_TYPE : RSS_CONTENT_TYPE
          end

          # Parses Accept header and returns the preferred format based on priority.
          #
          # @param accept_header [String, nil]
          # @return [Symbol, nil] preferred format (:json_feed, or nil meaning fallback to rss)
          def from_accept(accept_header)
            media_ranges = parse_accept(accept_header)
            return nil if media_ranges.empty?

            json_score = best_score(media_ranges, JSON_MEDIA_TYPES)
            rss_score = best_score(media_ranges, RSS_MEDIA_TYPES)

            return nil unless json_score
            return JSON_FEED if rss_score.nil?

            (json_score <=> rss_score)&.positive? ? JSON_FEED : nil
          end

          private

          # @param response [Rack::Response]
          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @return [void]
          def apply_cache_headers(response, result)
            return ::Html2rss::Web::HttpCache.expires_now(response) if result.status == :error

            ::Html2rss::Web::HttpCache.expires(response, result.ttl_seconds, cache_control: 'public')
          end

          # @param status [Symbol]
          # @return [Integer]
          def status_for(status)
            return 200 if status == :ok
            return 422 if status == :empty

            500
          end

          # @param request [Rack::Request]
          # @return [String]
          def request_path(request)
            path = request.respond_to?(:env) ? request.env['PATH_INFO'] : nil
            return path.to_s unless request_path_fallback?(request, path)

            request.path_info.to_s
          end

          # @param request [Rack::Request]
          # @return [String, nil]
          def accept_header(request)
            return request.get_header('HTTP_ACCEPT') unless request.respond_to?(:env)

            request.env['HTTP_ACCEPT'] || request.get_header('HTTP_ACCEPT')
          end

          # @param request [Rack::Request]
          # @param path [String, nil]
          # @return [Boolean]
          def request_path_fallback?(request, path)
            path.to_s.empty? && request.respond_to?(:path_info)
          end

          # @param accept_header [String, nil]
          # @return [Array<MediaRange>]
          def parse_accept(accept_header)
            accept_header.to_s.split(',').filter_map.with_index do |raw_range, position|
              build_media_range(raw_range, position)
            end
          end

          # @param raw_range [String]
          # @param position [Integer]
          # @return [MediaRange, nil]
          def build_media_range(raw_range, position)
            media_type, *parameter_parts = raw_range.strip.downcase.split(';')
            type, subtype = media_type.to_s.split('/', 2)
            return if type.to_s.empty? || subtype.to_s.empty?

            MediaRange.new(
              type: type,
              subtype: subtype,
              quality: extract_quality(parameter_parts),
              position: position
            )
          end

          # @param parameter_parts [Array<String>]
          # @return [Float]
          def extract_quality(parameter_parts)
            raw_value = parameter_parts
                        .map(&:strip)
                        .find { |part| part.start_with?('q=') }
                        &.split('=', 2)
                        &.last
            quality = raw_value ? Float(raw_value) : 1.0
            quality.clamp(0.0, 1.0)
          rescue ArgumentError
            1.0
          end

          # @param media_ranges [Array<MediaRange>]
          # @param candidates [Array<String>]
          # @return [Array(Float, Integer, Integer), nil]
          def best_score(media_ranges, candidates)
            media_ranges
              .filter { |range| range.quality.positive? && candidates.any? { |candidate| range.matches?(candidate) } }
              .map { |range| [range.quality, range.specificity, -range.position] }
              .max
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param format [Symbol]
          # @return [String]
          def render_success(result, format)
            if format == JSON_FEED
              serialize_json_feed(result.payload.feed)
            else
              result.payload.feed.to_s
            end
          end

          # @param result [Html2rss::Web::Feeds::Contracts::RenderResult]
          # @param format [Symbol]
          # @return [String]
          def render_empty(result, format)
            url = result.payload.url
            strategy = result.payload.strategy
            site_title = result.payload.site_title

            title = empty_feed_title(site_title)
            desc = empty_feed_description(url, strategy)
            timestamp = Time.now.utc

            if format == JSON_FEED
              JSON.generate({
                version: JSON_FEED_VERSION,
                title: title,
                home_page_url: url,
                description: desc,
                items: [{
                  id: url,
                  url: url,
                  title: 'Preview unavailable for this source',
                  content_text: empty_feed_item(url),
                  date_published: timestamp.iso8601
                }]
              }.compact)
            else
              build_rss(
                title: title,
                description: desc,
                link: url,
                items: [{
                  title: 'Preview unavailable for this source',
                  description: empty_feed_item(url),
                  link: url,
                  pubDate: timestamp
                }],
                timestamp: timestamp
              )
            end
          end

          # @param feed [RSS::Rss]
          # @return [String]
          def serialize_json_feed(feed)
            payload = {
              version: JSON_FEED_VERSION,
              title: feed.channel.title,
              home_page_url: feed.channel.link,
              description: feed.channel.description,
              items: feed.items.map { |item| serialize_json_item(item) }
            }.compact

            JSON.generate(payload)
          end

          # @param item [Object]
          # @return [Hash{Symbol=>Object}]
          def serialize_json_item(item)
            {
              id: item.respond_to?(:guid) && item.guid ? item.guid.content : (item.link || item.title),
              url: item.link,
              title: item.title,
              content_text: item.description,
              date_published: parse_date(item)
            }.compact
          end

          # @param item [Object]
          # @return [String, nil]
          def parse_date(item)
            value = item.respond_to?(:pubDate) ? item.pubDate : nil
            return value.iso8601 if value.respond_to?(:iso8601)

            Time.parse(value.to_s).utc.iso8601 if value
          rescue ArgumentError
            nil
          end

          # @param title [String]
          # @param description [String]
          # @param link [String, nil]
          # @param items [Array<Hash>]
          # @param timestamp [Time]
          # @return [String]
          def build_rss(title:, description:, link: nil, items: [], timestamp: nil)
            ::RSS::Maker.make('2.0') do |maker|
              # Apply stylesheets
              stylesheets = Html2rss.defaults.stylesheets.map do |s|
                Html2rss::FeedBuilder::Rss::Stylesheet.new(**s)
              end
              Html2rss::FeedBuilder::Rss::Stylesheet.add(maker, stylesheets)

              # Channel details
              now = timestamp || Time.now
              maker.channel.title = title.to_s
              maker.channel.description = description.to_s
              maker.channel.link = link.to_s
              maker.channel.lastBuildDate = now
              maker.channel.pubDate = now

              # Items
              items.each do |item|
                maker.items.new_item do |i|
                  i.title = item[:title].to_s
                  i.description = item[:description].to_s
                  i.link = item[:link].to_s
                  i.pubDate = item[:pubDate] || now
                end
              end
            end.to_s
          end

          # @param site_title [String, nil]
          # @return [String]
          def empty_feed_title(site_title)
            site_title ? "#{site_title} - Content Extraction Issue" : 'Content Extraction Issue'
          end

          # @param url [String]
          # @param strategy [String]
          # @return [String]
          def empty_feed_description(url, strategy)
            format(EMPTY_FEED_DESCRIPTION_TEMPLATE, url: url, strategy: strategy)
          end

          # @param url [String]
          # @return [String]
          def empty_feed_item(url)
            format(EMPTY_FEED_ITEM_TEMPLATE, url: url)
          end
        end
      end
      # rubocop:enable Metrics/ModuleLength, Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
    end
  end
end
