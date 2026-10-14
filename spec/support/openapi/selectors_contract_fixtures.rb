# frozen_string_literal: true

##
# Shared accept/reject payloads for SelectorsDocument ↔ OpenAPI parity.
#
# Accept rows are selectors subtrees (the value create posts under +selectors+).
# Reject rows are full client fragments for {Html2rss::Web::SelectorsDocument.from_client}.
module SelectorsContractFixtures
  EMPTY = {}.freeze
  ITEMS_ONLY = { items: { selector: 'article' }.freeze }.freeze
  ORDER_REVERSE = { items: { selector: 'article', order: 'reverse' }.freeze }.freeze
  # Reused by Phase 05 create→token coverage.
  PAGINATION_INTEGER = { items: { selector: 'article', pagination: 2 }.freeze }.freeze
  PAGINATION_REL_NEXT = {
    items: { selector: 'article', pagination: { strategy: 'rel_next' }.freeze }.freeze
  }.freeze

  ACCEPT = [
    ['empty', EMPTY],
    ['items-only', ITEMS_ONLY],
    ['items.order reverse', ORDER_REVERSE],
    ['items.pagination integer', PAGINATION_INTEGER],
    ['items.pagination rel_next', PAGINATION_REL_NEXT]
  ].map(&:freeze).freeze

  REJECT = [
    ['empty items.selector', { selectors: { items: { selector: '' }.freeze }.freeze }.freeze],
    [
      'denied root channel',
      { channel: { url: 'https://evil.example' }.freeze, selectors: ITEMS_ONLY }.freeze
    ]
  ].map(&:freeze).freeze
end
