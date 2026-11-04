# frozen_string_literal: true

require "administrate/base_dashboard"

class ProConnectMigrationDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    source_email: Field::String,
    pro_connect_email: Field::String,
    state: EnumField,
    user: Field::BelongsTo,
    target_user: Field::BelongsTo,
    parent: Field::BelongsTo,
    children: Field::HasMany,
    procedure_ids: Field::String.with_options(searchable: false),
    groupe_instructeur_ids: Field::String.with_options(searchable: false),
    shared: Field::String.with_options(
      getter: -> (field) {
        {
          true => I18n.t('manager.pro_connect_migrations.shared.open'),
          false => I18n.t('manager.pro_connect_migrations.shared.closed'),
        }[field.resource.shared]
      }
    ),
    code_sent_at: Field::DateTime,
    code_attempts: Field::Number,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  COLLECTION_ATTRIBUTES = [:id, :source_email, :pro_connect_email, :state, :created_at].freeze

  SHOW_PAGE_ATTRIBUTES = [
    :source_email, :pro_connect_email, :state, :shared, :user, :target_user, :parent, :children,
    :procedure_ids, :groupe_instructeur_ids, :code_sent_at, :code_attempts, :created_at, :updated_at,
  ].freeze

  COLLECTION_FILTERS = {
    completed: -> (resources) { resources.completed },
    support: -> (resources) { resources.where(state: ProConnectMigration::SUPPORT_STATES) },
  }.freeze

  def display_resource(migration)
    [migration.source_email, migration.pro_connect_email].compact.join(' → ')
  end
end
