# frozen_string_literal: true

class ProConnectMigrationsController < ApplicationController
  include ProConnectMigrationConcern

  before_action :authenticate_administrateur!, only: :completed
  before_action :set_migration_waiting_for_code, only: [:code, :verify_code, :resend_code]

  def show
    @migration = pro_connect_migration_in_session(ProConnectMigration.pending)
    redirect_to new_user_session_path if @migration.nil?
  end

  def support
    @migration = pro_connect_migration_in_session(ProConnectMigration.sent_to_support)
    redirect_to new_user_session_path if @migration.nil?
  end

  def code
  end

  def verify_code
    return retry_or_start_over if !@migration.verify_code(params[:code])

    auth = kept_pro_connect_authentication
    forget_pro_connect_migration
    return redirect_to new_user_session_path, alert: t('.conflict') if !@migration.rename!(auth:)

    sign_in_with_pro_connect(@migration.target_user, id_token: auth.id_token, mfa: true)
    remember_administrateur_device
    redirect_to pro_connect_migration_completed_path
  end

  def resend_code
    if @migration.resend_code!(browser)
      redirect_to pro_connect_migration_code_path, notice: t('.sent', source_email: @migration.source_email)
    else
      redirect_to pro_connect_migration_code_path, alert: t('.too_soon')
    end
  end

  def completed
    redirect_to admin_procedures_path if !current_administrateur.pro_connect_required_at?
  end

  private

  def set_migration_waiting_for_code
    @migration = pro_connect_migration_in_session(ProConnectMigration.waiting_for_code)
    redirect_to new_user_session_path if @migration.nil?
  end

  def retry_or_start_over
    if @migration.reload.code_usable?
      @error = t('pro_connect_migrations.verify_code.wrong_code')
      render :code, status: :unprocessable_content
    else
      forget_pro_connect_migration
      redirect_to new_user_session_path, alert: t('pro_connect_migrations.verify_code.expired_code')
    end
  end
end
