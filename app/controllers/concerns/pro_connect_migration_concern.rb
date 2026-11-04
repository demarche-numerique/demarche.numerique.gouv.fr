# frozen_string_literal: true

module ProConnectMigrationConcern
  extend ActiveSupport::Concern

  SESSION_KEY = :pro_connect_migration_id
  ID_TOKEN_COOKIE_NAME = :proConnect_migration_id_token
  IDENTITY_COOKIE_NAME = :proConnect_migration_identity

  private

  def start_pro_connect_migration(user)
    session[SESSION_KEY] = ProConnectMigration.create!(user:, source_email: user.email).id
    redirect_to pro_connect_migration_path
  end

  def pro_connect_migration_in_session(scope)
    scope.find_by(id: session[SESSION_KEY])
  end

  def forget_pro_connect_migration
    session.delete(SESSION_KEY)
    cookies.delete(ID_TOKEN_COOKIE_NAME)
    cookies.delete(IDENTITY_COOKIE_NAME)
  end

  def kept_pro_connect_authentication
    identity = cookies.encrypted[IDENTITY_COOKIE_NAME].symbolize_keys
    ProConnectService::Authentication.new(id_token: cookies.encrypted[ID_TOKEN_COOKIE_NAME], **identity)
  end
end
