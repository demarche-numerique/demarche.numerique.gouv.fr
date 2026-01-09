# frozen_string_literal: true

class DossierPreviewService
  include Rails.application.routes.url_helpers

  def initialize(procedure:, current_user:)
    @procedure = procedure
    @user = current_user
  end

  def dossier
    @dossier ||= fetch_or_build_dossier
  end

  def edit_path
    apercu_admin_procedure_path(@procedure)
  end

  private

  attr_reader :procedure, :user

  def fetch_or_build_dossier
    dossier = Dossier
      .create_with(autorisation_donnees: true)
      .find_or_initialize_by(
        revision: procedure.active_revision,
        user: user,
        for_procedure_preview: true,
        state: Dossier.states.fetch(:brouillon)
      )

    if dossier.new_record?
      dossier.build_default_values
      dossier.save!
    end

    dossier.with_champs
  end
end
