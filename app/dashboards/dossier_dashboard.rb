# frozen_string_literal: true

require "administrate/base_dashboard"

class DossierDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number.with_options(searchable: true),
    procedure: Field::HasOne,
    state: EnumField,
    user: Field::BelongsTo,
    text_summary: Field::String.with_options(searchable: false),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    hidden_by_user_at: Field::DateTime,
    hidden_by_administration_at: Field::DateTime,
    hidden_by_expired_at: Field::DateTime,
    depose_at: Field::DateTime,
    en_construction_at: Field::DateTime,
    en_instruction_at: Field::DateTime,
    processed_at: Field::DateTime,
    root_public_champs: ChampCollectionField,
    groupe_instructeur: Field::BelongsTo,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = [
    :id,
    :procedure,
    :created_at,
    :state,
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = [
    :user,
    :text_summary,
    :state,
    :procedure,
    :groupe_instructeur,
    :root_public_champs,
    :created_at,
    :updated_at,
    :hidden_by_user_at,
    :hidden_by_administration_at,
    :hidden_by_expired_at,
    :depose_at,
    :en_construction_at,
    :en_instruction_at,
    :processed_at,
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = [].freeze

  # Overwrite this method to customize how users are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(user)
  #   "User ##{user.id}"
  # end
end
