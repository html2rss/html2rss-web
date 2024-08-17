# frozen_string_literal: true

module Html2rss
  module Web
    class App
      def handle_html2rss_configs(request, _folder_name, _config_name_with_ext)
        path = RequestPath.new(request)

        Html2rssFacade.from_config(path.full_config_name, typecast_params) do |config|
          response['Content-Type'] = 'text/xml'
          HttpCache.expires(response, config.ttl * 60, cache_control: 'public')
        end
      end
    end
  end
end
