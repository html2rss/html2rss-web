# frozen_string_literal: true

require 'json'

module Html2rss
  module Web
    module Api
      module V1
        module CreateFeed
          ##
          # Parses, normalizes and authorizes the client-supplied feed creation input.
          module Input
            MAX_BODY_BYTES = 64 * 1024
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
                raise BadRequestError, 'Payload too large' if request.content_length.to_i > MAX_BODY_BYTES

                params = request_params(request)
                FeedMetadata::CreateParams.new(url: validated_url(params['url'], account),
                                               name: params['name'].to_s.strip.then { it unless it.empty? },
                                               selectors: validated_selectors(params['selectors']))
              end

              private

              def request_params(request)
                return request.params unless request.env['CONTENT_TYPE'].to_s.include?('application/json')

                request.GET.merge(parsed_json_body(request))
              end

              def parsed_json_body(request)
                raw_body = read_limited_body(request)
                return {} if raw_body.strip.empty?

                parsed = JSON.parse(raw_body)
                raise BadRequestError, 'Invalid JSON payload' unless parsed.is_a?(Hash)

                parsed
              rescue JSON::ParserError
                raise BadRequestError, 'Invalid JSON payload'
              end

              def read_limited_body(request)
                request.body.read(MAX_BODY_BYTES + 1).to_s.tap do |raw_body|
                  request.body.rewind
                  raise BadRequestError, 'Payload too large' if raw_body.bytesize > MAX_BODY_BYTES
                end
              end

              def validated_url(raw_url, account)
                url = normalized_input_url(raw_url)
                raise BadRequestError, 'URL parameter is required' if url.empty?

                url = UrlValidator.canonical_url(url) or raise BadRequestError, 'Invalid URL format'
                raise ForbiddenError, 'URL not allowed for this account' unless UrlValidator.url_allowed?(account, url)

                url
              end

              # Selectors are authored in the studio, so the studio kill switch applies to them.
              def validated_selectors(raw)
                selectors = SelectorsDocument.parse(raw)
                raise ForbiddenError, 'Studio is disabled' if selectors && !Flags.studio_enabled?

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
