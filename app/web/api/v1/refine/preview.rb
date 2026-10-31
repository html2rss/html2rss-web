# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module Refine
          ##
          # Live extraction preview for the config a signed token would serve.
          #
          # Builds config through {Feeds::GeneratorInput}, the same expansion serving uses.
          # Selects {Html2rss::Test::Result} fields explicitly: +#to_h+ also carries the full RSS.
          module Preview
            class << self
              # @param request [Rack::Request]
              # @return [Hash{Symbol=>Object}] API success payload
              def call(request)
                account = Access.ensure_allowed!(request, live_fetch: true)
                body = JsonBody.object(request)
                url = Access.page_url!(body['url'], account)
                config = Feeds::GeneratorInput.for_token(url:, selectors: SelectorsDocument.parse(body['selectors']))

                Response.success(response: request.response, data: fields(Html2rss.test(config, min_items: 1)))
              end

              private

              # @param result [Html2rss::Test::Result]
              # @return [Hash{Symbol=>Object}]
              def fields(result)
                {
                  item_count: result.item_count,
                  sample_items: result.sample_items,
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
end
