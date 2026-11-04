# frozen_string_literal: true

module Html2rss
  module Web
    module Api
      module V1
        module CreateFeed
          ##
          # Parses, normalizes and authorizes the client-supplied feed creation input.
          module Input
            ABSOLUTE_URL_REGEXP = %r{\A[a-z][a-z0-9+\-.]*://}i
            HOSTNAME_INPUT_REGEXP = %r{
              \A(localhost(?::\d+)?|(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?|(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?)
              (?:[/?#].*)?\z
            }ix

            class << self
              # @param request [Rack::Request] HTTP request (query, form or JSON body).
              # @param account [Hash] authenticated account.
              # @return [FeedMetadata::CreateParams]
              # @raise [BadRequestError, ForbiddenError] on malformed or disallowed input.
              def call(request, account)
                JsonBody.enforce_limit!(request)
                params = request_params(request)
                FeedMetadata::CreateParams.new(url: validated_url(params['url'], account),
                                               name: params['name'].to_s.strip.then { it unless it.empty? },
                                               selectors: validated_selectors(params['selectors']))
              end

              private

              def request_params(request)
                return request.params unless request.env['CONTENT_TYPE'].to_s.include?('application/json')

                request.GET.merge(JsonBody.object(request))
              end

              def validated_url(raw_url, account)
                url = normalized_input_url(raw_url)
                raise BadRequestError, 'URL parameter is required' if url.empty?

                url = UrlValidator.canonical_url(url) or raise BadRequestError, 'Invalid URL format'
                raise ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(account, url)

                url
              end

              # Selectors are authored through Refine, so the kill switch applies to them.
              def validated_selectors(raw)
                selectors = SelectorsDocument.parse(raw)
                raise ForbiddenError, 'Refine is disabled' if selectors && !Flags.refine_enabled?

                selectors
              end

              def normalized_input_url(raw_url)
                url = raw_url.to_s.strip
                return url if url.empty? || ABSOLUTE_URL_REGEXP.match?(url)
                return "https:#{url}" if url.start_with?('//')

                HOSTNAME_INPUT_REGEXP.match?(url) ? "https://#{url}" : url
              end
            end
          end
        end
      end
    end
  end
end
