# frozen_string_literal: true

module Html2rss
  module Web
    module Catalog
      ##
      # Sole owner of featured starter selection for +meta.starters+.
      #
      # Prefers +ok+, then +unknown+. Never features +empty+/+error+ when any
      # preferred alternative exists. Cold-seed IDs break ties among equals only
      # and are private to this module (not exported to clients).
      module Starters
        LIMIT = 3

        COLD_SEED_IDS = %w[
          fao.org/newsroom
          ftc.gov/press-releases
          icrc.org/news
        ].freeze
        private_constant :COLD_SEED_IDS

        class << self
          ##
          # Picks up to +limit+ catalog entry ids for featured starters.
          #
          # @param entries [Array<Html2rss::Web::Catalog::Entry>]
          # @param limit [Integer]
          # @return [Array<String>]
          def pick(entries, limit: LIMIT)
            preferred = rank(select_states(entries, :ok)) + rank(select_states(entries, :unknown))
            chosen = preferred.first(limit)
            return chosen.map(&:id) unless chosen.empty?

            rank(entries).first(limit).map(&:id)
          end

          private

          # @param entries [Array<Html2rss::Web::Catalog::Entry>]
          # @param state [Symbol]
          # @return [Array<Html2rss::Web::Catalog::Entry>]
          def select_states(entries, state)
            entries.select { it.last_result.state == state }
          end

          # Stable by cold-seed index then id.
          #
          # @param entries [Array<Html2rss::Web::Catalog::Entry>]
          # @return [Array<Html2rss::Web::Catalog::Entry>]
          def rank(entries)
            entries.sort_by { |entry| [cold_seed_rank(entry.id), entry.id] }
          end

          # @param id [String]
          # @return [Integer]
          def cold_seed_rank(id)
            index = COLD_SEED_IDS.index(id)
            index.nil? ? COLD_SEED_IDS.size : index
          end
        end
      end
    end
  end
end
