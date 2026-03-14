# frozen_string_literal: true

module Html2rss
  module Web
    ##
    # Immutable dependency wiring root for the application.
    #
    # This keeps boot assembly explicit so route entrypoints receive all runtime
    # collaborators from one place instead of resolving module constants inline.
    module AppContext
      ##
      # Boot dependency graph for the app process.
      Context = Data.define(
        :environment_validator,
        :local_config,
        :flags,
        :auth,
        :security_logger,
        :observability,
        :routes_api_v1,
        :routes_static,
        :api_health,
        :api_strategies,
        :api_feeds
      )

      class << self
        # @return [Context]
        def build
          Context.new(**core_dependencies, **api_dependencies)
        end

        private

        # @return [Hash{Symbol=>Object}]
        def core_dependencies
          {
            environment_validator: EnvironmentValidator,
            local_config: LocalConfig,
            flags: Flags,
            auth: Auth,
            security_logger: SecurityLogger,
            observability: Observability
          }
        end

        # @return [Hash{Symbol=>Object}]
        def api_dependencies
          {
            routes_api_v1: Routes::ApiV1,
            routes_static: Routes::Static,
            api_health: Api::V1::Health,
            api_strategies: Api::V1::Strategies,
            api_feeds: Api::V1::Feeds
          }
        end
      end
    end
  end
end
