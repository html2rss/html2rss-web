# frozen_string_literal: true

module Html2rss
  module Web
    class App
      def handle_local_config_feeds(request, _config_name_with_ext)
        path = RequestPath.new(request)

        Html2rssFacade.from_local_config(path.full_config_name, typecast_params) do |config|
          response['Content-Type'] = CONTENT_TYPE_RSS
          HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
        end
      end
    end
  end
end
