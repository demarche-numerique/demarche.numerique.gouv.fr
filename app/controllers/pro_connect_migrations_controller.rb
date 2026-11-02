# frozen_string_literal: true

class ProConnectMigrationsController < ApplicationController
  include ProConnectMigrationConcern

  before_action :authenticate_administrateur!, only: :completed

  def show
    @migration = pro_connect_migration_in_session(ProConnectMigration.pending)
    redirect_to new_user_session_path if @migration.nil?
  end

  def support
    @migration = pro_connect_migration_in_session(ProConnectMigration.sent_to_support)
    redirect_to new_user_session_path if @migration.nil?
  end

  def completed
    redirect_to admin_procedures_path if !current_administrateur.pro_connect_required_at?
  end
end
