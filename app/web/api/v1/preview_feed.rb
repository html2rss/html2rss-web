# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        ##
        # Live extraction preview for a token config carrying a selectors document.
        #
        # Builds the config through {Feeds::GeneratorInput} and selects
        # {Html2rss::Test::Result} fields. Never forwards +#to_h+, which includes +rss:+.
        # A later preview of the same canonical URL is replayed by {PreviewPageCache}.
        module PreviewFeed
          class << self
            ##
            # @param request [Rack::Request]
            # @return [Hash{Symbol=>Object}]
            def call(request)
              account = StudioRequest.ensure_allowed!(request, live_fetch: true)
              body = StudioRequest.json_object(request)
              url = StudioRequest.allowed_url(body['url'], account)
              config = PreviewPageCache.replay(url, preview_config(url, body['selectors']))
              result = Html2rss.test(config, min_items: 1)
              PreviewPageCache.store(url, result)
              Response.success(response: request.response, data: preview_fields(result))
            end

            private

            # @param url [String]
            # @param selectors [Object]
            # @return [Hash{Symbol=>Object}]
            def preview_config(url, selectors)
              Feeds::GeneratorInput.for_token(url:, selectors: selectors_document(selectors))
            end

            # @param selectors [Object]
            # @return [Html2rss::Web::SelectorsDocument, nil]
            def selectors_document(selectors)
              return if selectors.nil?

              SelectorsDocument.from_client({ selectors: })
            end

            # Selected fields only. {Html2rss::Test::Result#to_h} also carries +rss+.
            # Successful previews rebuild the meadow from that RSS, capped here.
            #
            # @param result [Html2rss::Test::Result]
            # @return [Hash{Symbol=>Object}]
            def preview_fields(result)
              {
                item_count: result.item_count,
                sample_items: PreviewSamples.from_result(result),
                quality_report: result.quality_report&.to_h,
                failure_kind: result.failure_kind&.to_sym,
                validation_issues: result.validation_issues&.map(&:to_h)
              }
            end
          end
        end
      end
    end
  end
end
