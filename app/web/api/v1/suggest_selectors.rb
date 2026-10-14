# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Ranked capture-derived selector candidates for the refinement studio.
        #
        # +Html2rss.capture+ publishes buckets on +CaptureResult#candidates+.
        # Empty buckets are a successful response.
        module SuggestSelectors
          # Upper bound for the client-supplied items selector hint.
          MAX_ITEMS_SELECTOR_LENGTH = 256
          BUCKET_NAMES = %i[items title link published].freeze

          class << self
            ##
            # @param request [Rack::Request]
            # @return [Hash{Symbol=>Object}]
            def call(request)
              account = StudioRequest.ensure_allowed!(request, live_fetch: true)
              body = StudioRequest.json_object(request)
              url = StudioRequest.allowed_url(body['url'], account)
              captured = Html2rss.capture(
                url,
                strategy: :auto,
                items_selector: hint(body['items_selector']),
                **replay_options(url)
              )
              Response.success(response: request.response, data: suggestion(captured))
            end

            private

            # @param url [String]
            # @return [Hash{Symbol=>String}]
            def replay_options(url)
              path = PreviewPageCache.path_for(url)
              path ? { local_file_path: path } : {}
            end

            # @param raw [Object]
            # @return [String, nil]
            # @raise [Html2rss::Web::BadRequestError] when the hint exceeds the cap
            def hint(raw)
              text = raw.to_s.strip
              raise BadRequestError, 'items_selector is too long' if text.length > MAX_ITEMS_SELECTOR_LENGTH

              text.empty? ? nil : text
            end

            # @param captured [Html2rss::Capture::CaptureResult]
            # @return [Hash{Symbol=>Object}]
            def suggestion(captured)
              {
                candidates: candidate_buckets(captured.candidates),
                segment_strategy: captured.segment_strategy&.to_s,
                admission_drops: captured.admission_drops
              }
            end

            # @param raw [Hash, nil]
            # @return [Hash{Symbol=>Array<Hash>}]
            def candidate_buckets(raw)
              buckets = raw.is_a?(Hash) ? raw : {}
              BUCKET_NAMES.to_h do |name|
                entries = bucket(buckets, name)
                [name, name == :items ? item_entries(entries) : field_entries(entries)]
              end
            end

            # @param buckets [Hash]
            # @param name [Symbol]
            # @return [Array]
            def bucket(buckets, name)
              value = buckets.fetch(name) { buckets[name.to_s] }
              value.is_a?(Array) ? value : []
            end

            # @param entries [Array]
            # @return [Array<Hash>]
            def item_entries(entries)
              entries.filter_map { item_entry(it) }
            end

            # @param entry [Object]
            # @return [Hash, nil]
            def item_entry(entry)
              selector = selector_text(entry)
              sample = sample_text(entry)
              return unless selector && sample

              { selector:, enhance: enhanced?(entry), sample: }
            end

            # @param entries [Array]
            # @return [Array<Hash>]
            def field_entries(entries)
              entries.filter_map do |entry|
                selector = selector_text(entry)
                sample = sample_text(entry)
                { selector:, sample: } if selector && sample
              end
            end

            # @param entry [Object]
            # @return [String, nil]
            def selector_text(entry)
              return unless entry.is_a?(Hash)

              text = (entry[:selector] || entry['selector']).to_s.strip
              text.empty? ? nil : text
            end

            # @param entry [Hash]
            # @return [String, nil]
            def sample_text(entry)
              return unless entry.is_a?(Hash)

              text = (entry[:sample] || entry['sample']).to_s.strip
              text.empty? ? nil : text
            end

            # @param entry [Hash]
            # @return [Boolean]
            def enhanced?(entry)
              flag = entry.key?(:enhance) ? entry[:enhance] : entry['enhance']
              flag == true
            end
          end
        end
      end
    end
  end
end
