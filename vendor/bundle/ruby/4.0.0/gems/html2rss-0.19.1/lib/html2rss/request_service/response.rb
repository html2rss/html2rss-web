# frozen_string_literal: true

require 'nokogiri'

module Html2rss
  class RequestService
    ##
    # To be used by strategies to provide their response.
    class Response
      ##
      # @param body [String] the body of the response
      # @param url [Html2rss::Url] the final request URL
      # @param headers [Hash] the headers of the response
      # @param status [Integer, nil] the HTTP status code when available
      def initialize(body:, url:, headers: {}, status: nil)
        @body = body

        headers = headers.dup
        headers.transform_keys!(&:to_s)
        HashUtil.assert_string_keys!(headers, context: 'response headers', deep: false)

        @headers = headers
        @status = status
        @url = url
      end

      # @return [String] the raw body of the response
      attr_reader :body

      # @return [Hash{String => Object}] the headers of the response
      attr_reader :headers

      # @return [Integer, nil] the HTTP status code when known
      attr_reader :status

      # @return [Html2rss::Url] the URL of the response
      attr_reader :url

      # @return [String] normalized content type header value
      def content_type = header('content-type').to_s

      # @return [Boolean] whether response content is JSON
      def json_response? = content_type.include?('application/json')

      # @return [Boolean] whether response content is HTML
      def html_response? = content_type.include?('text/html')

      ##
      # @return [Nokogiri::HTML::Document, Hash] the parsed body of the response, frozen object
      # @raise [UnsupportedResponseContentType] if the content type is not supported
      def parsed_body
        @parsed_body ||= if html_response?
                           Nokogiri::HTML(body).tap do |doc|
                             # Remove comments from the document to avoid processing irrelevant content
                             doc.xpath('//comment()').each(&:remove)
                           end.freeze
                         elsif json_response?
                           JSON.parse(body, symbolize_names: true).freeze
                         else
                           raise UnsupportedResponseContentType, "Unsupported content type: #{content_type}"
                         end
      end

      private

      # @param name [String] canonical header name
      # @return [Object, nil] header value when present
      def header(name)
        headers.fetch(name) do
          headers.find { |key, _value| key.casecmp?(name) }&.last
        end
      end
    end
  end
end
