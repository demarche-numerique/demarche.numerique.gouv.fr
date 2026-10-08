# frozen_string_literal: true

require "administrate/base_dashboard"

class UserDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number.with_options(searchable: true),
    email: Field::String,
    email_verified_at: Field::DateTime,
    confirmed?: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    blocked_at: Field::DateTime,
    blocked_reason: Field::String,
    current_sign_in_at: Field::DateTime,
    dossiers: Field::HasMany.with_options(sort_by: :created_at, direction: :desc),
    dossiers_invites: Field::HasMany,
    otp_attempt: OtpAttemptField,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = [
    :id,
    :email,
    :created_at,
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = [
    :dossiers,
    :dossiers_invites,
    :id,
    :email,
    :confirmed?,
    :email_verified_at,
    :current_sign_in_at,
    :created_at,
    :blocked_at,
    :blocked_reason,
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = [
    :email,
    (:otp_attempt if SUPER_ADMIN_OTP_ENABLED),
  ].compact.freeze

  # Overwrite this method to customize how users are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(user)
    user.email
  end
end
