# frozen_string_literal: true

module Html2rss
  class RequestSession
    ##
    # Traverses a rel=next pagination chain for selector-driven extraction.
    class RelNextPager
      include Enumerable

      ##
      # @param session [RequestSession] request session used to execute follow-ups
      # @param initial_response [RequestService::Response] first page response
      # @param max_pages [Integer] configured page budget, including the initial page
      # @param logger [Logger] logger used for pagination stop reasons
      def initialize(session:, initial_response:, max_pages:, logger: Html2rss::Log)
        @session = session
        @initial_response = initial_response
        @max_pages = max_pages
        @logger = logger
      end

      ##
      # Iterates over all paginated responses, beginning with the initial response.
      #
      # @yield [RequestService::Response] each page response
      # @return [Enumerator] enumerator when no block is given
      def each
        return enum_for(:each) unless block_given?

        yield initial_response

        current_response = initial_response
        session.effective_page_budget(max_pages).pred.times do
          next_url = next_page_url(current_response)
          break unless follow_up_allowed?(next_url)

          current_response = fetch_follow_up_response_or_stop(next_url, current_response.url)
          break unless current_response

          yield current_response
        end
      end

      private

      attr_reader :session, :initial_response, :max_pages, :logger

      def next_page_url(page_response)
        href = page_response.parsed_body.at_css('link[rel~="next"][href], a[rel~="next"][href]')&.[]('href')
        return nil if href.nil? || href.empty?

        Html2rss::Url.from_relative(href, page_response.url)
      end

      def follow_up_allowed?(next_url)
        next_url && !session.visited?(next_url)
      end

      def fetch_follow_up_response_or_stop(next_url, origin_url)
        session.follow_up(url: next_url, relation: :pagination, origin_url:)
      rescue RequestService::RequestBudgetExceeded => error
        logger.warn(
          "#{self.class}: pagination stopped at #{next_url} - #{error.message}. " \
          "Retry with --max-requests #{session.max_requests + 1} or increase request.max_requests in the config."
        )
        nil
      end
    end
  end
end
