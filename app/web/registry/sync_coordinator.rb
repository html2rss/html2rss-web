# frozen_string_literal: true

module Html2rss
  module Web
    module Registry
      ##
      # Serializes sync work per registry id to avoid concurrent bundle swaps.
      module SyncCoordinator
        REGISTRY_MUTEXES = Hash.new { |mutexes, registry_id| mutexes[registry_id] = Mutex.new }

        module_function

        ##
        # @param registry_id [String, Symbol]
        # @yield runs sync work exclusively for the registry id
        # @return [Object] block result
        def run(registry_id, &)
          REGISTRY_MUTEXES[registry_id.to_s].synchronize(&)
        end
      end
    end
  end
end
