# frozen_string_literal: true

module ProConnectMigrationConcern
  extend ActiveSupport::Concern

  SESSION_KEY = :pro_connect_migration_id

  private

  def start_pro_connect_migration(user)
    session[SESSION_KEY] = ProConnectMigration.create!(user:, source_email: user.email).id
    redirect_to pro_connect_migration_path
  end

  def pro_connect_migration_in_session(scope)
    scope.find_by(id: session[SESSION_KEY])
  end
end
