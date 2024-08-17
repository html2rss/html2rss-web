# frozen_string_literal: true

module Html2rss
  module Web
    class App
      def handle_error(error) # rubocop:disable Metrics/MethodLength
        case error
        when Html2rss::Config::ParamsMissing,
             Roda::RodaPlugins::TypecastParams::Error
          set_error_response('Parameters missing or invalid', 422)
        when Html2rss::AttributePostProcessors::UnknownPostProcessorName,
             Html2rss::ItemExtractors::UnknownExtractorName,
             Html2rss::Config::ChannelMissing
          set_error_response('Invalid feed config', 422)
        when LocalConfig::NotFound,
             Html2rss::Configs::ConfigNotFound
          set_error_response('Feed config not found', 404)
        else
          set_error_response('Internal Server Error', 500)
        end

        @show_backtrace = self.class.development?
        @error = error
        view 'error'
      end

      private

      def set_error_response(page_title, status)
        @page_title = page_title
        response.status = status
      end
    end
  end
end
