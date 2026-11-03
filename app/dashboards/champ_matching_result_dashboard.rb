# frozen_string_literal: true

require "administrate/base_dashboard"

class ChampMatchingResultDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    stable_id: Field::Number.with_options(sortable: false),
    libelle: Field::String.with_options(sortable: false),
    partner_stable_id: Field::Number.with_options(sortable: false),
    partner_libelle: Field::String.with_options(sortable: false),
    matching_users_count: Field::Number.with_options(sortable: false),
    common_users_count: Field::Number.with_options(sortable: false),
    score: Field::Number.with_options(sortable: false, decimals: 2),
    confirmed: Field::Boolean.with_options(sortable: false),
  }.freeze

  COLLECTION_ATTRIBUTES = ATTRIBUTE_TYPES.keys.freeze
  SHOW_PAGE_ATTRIBUTES = [].freeze
  COLLECTION_FILTERS = {}.freeze
end
