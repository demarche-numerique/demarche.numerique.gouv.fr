# frozen_string_literal: true

class ProConnectMigrationsController < ApplicationController
  include ProConnectMigrationConcern

  def show
    @migration = pro_connect_migration_in_session(ProConnectMigration.pending)
    redirect_to new_user_session_path if @migration.nil?
  end
end
