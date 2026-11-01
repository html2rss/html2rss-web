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
            SAMPLE_LIMIT = 100

            class << self
              # @param request [Rack::Request]
              # @return [Hash{Symbol=>Object}] API success payload
              def call(request)
                account = Access.ensure_allowed!(request, live_fetch: true)
                body = JsonBody.object(request)
                url = Access.page_url!(body['url'], account)
                config = Feeds::GeneratorInput.for_token(url:, strategy: body['strategy'],
                                                         selectors: SelectorsDocument.parse(body['selectors']))

                Response.success(response: request.response, data: fields(Html2rss.test(config, min_items: 1)))
              end

              private

              # @param result [Html2rss::Test::Result]
              # @return [Hash{Symbol=>Object}]
              def fields(result)
                {
                  item_count: result.item_count,
                  sample_items: samples(result),
                  quality_report: result.quality_report&.to_h,
                  failure_kind: result.failure_kind&.to_sym,
                  validation_issues: result.validation_issues&.map(&:to_h)
                }
              end

              # The gem keeps three samples; the person comparing selectors wants to see the list, so read
              # up to {SAMPLE_LIMIT} items from the generated RSS and fall back to the gem's samples.
              # @param result [Html2rss::Test::Result]
              # @return [Array<Hash{Symbol=>Object}>] title, url and ISO 8601 published_at per item
              def samples(result)
                return result.sample_items unless result.rss

                Nokogiri::XML(result.rss).xpath('//item').first(SAMPLE_LIMIT).map { |item| sample(item) }
              end

              # @param item [Nokogiri::XML::Node] an RSS +item+ node
              # @return [Hash{Symbol=>Object}] title, url and published_at
              def sample(item)
                { title: item.at_xpath('title')&.text.to_s.strip, url: item.at_xpath('link')&.text.to_s,
                  published_at: published_at(item.at_xpath('pubDate')&.text) }
              end

              # @param text [String, nil] RFC 2822 date from the feed
              # @return [String, nil] ISO 8601, or nil when absent or unparsable
              def published_at(text)
                Time.rfc2822(text.to_s).iso8601 unless text.to_s.strip.empty?
              rescue ArgumentError
                nil
              end
            end
          end
        end
      end
    end
  end
end
