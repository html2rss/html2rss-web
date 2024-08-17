# frozen_string_literal: true

module Html2rss
  module Web
    class App
      def handle_health_check
        HttpCache.expires_now(response)

        with_basic_auth(realm: HealthCheck,
                        username: HealthCheck::Auth.username,
                        password: HealthCheck::Auth.password) do
          HealthCheck.run
        end
      end
    end
  end
end
