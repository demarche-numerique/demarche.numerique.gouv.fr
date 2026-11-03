# frozen_string_literal: true

module ProConnectMigrationConcern
  extend ActiveSupport::Concern

  SESSION_KEY = :pro_connect_migration_id
  CODE_VERIFIED_SESSION_KEY = :pro_connect_migration_code_verified_id
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
    session.delete(CODE_VERIFIED_SESSION_KEY)
    cookies.delete(ID_TOKEN_COOKIE_NAME)
    cookies.delete(IDENTITY_COOKIE_NAME)
  end

  # Two cookies: an id_token signed with ProConnect's 4096-bit RSA key fills
  # 3 KB once encrypted, and a long identity next to it passes the 4 KB a
  # browser keeps per cookie.
  def keep_pro_connect_authentication(auth)
    identity = { user_info: auth.user_info.slice(*ProConnectInformation::USER_INFO_KEYS), amr: auth.amr, acr: auth.acr }
    options = { expires: ProConnectMigration::PENDING_FOR.from_now, secure: Rails.env.production?, httponly: true }
    cookies.encrypted[ID_TOKEN_COOKIE_NAME] = options.merge(value: auth.id_token)
    cookies.encrypted[IDENTITY_COOKIE_NAME] = options.merge(value: identity)
  end

  def kept_pro_connect_authentication
    identity = cookies.encrypted[IDENTITY_COOKIE_NAME].symbolize_keys
    ProConnectService::Authentication.new(id_token: cookies.encrypted[ID_TOKEN_COOKIE_NAME], **identity)
  end
end
