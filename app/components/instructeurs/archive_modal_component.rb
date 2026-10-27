# frozen_string_literal: true

class Instructeurs::ArchiveModalComponent < ApplicationComponent
  def initialize(procedure_id:, dossier_id: nil)
    @procedure_id = procedure_id
    @dossier_id = dossier_id
  end

  def render?
    current_instructeur.present? && !current_instructeur.archive_warning_dismissed_for?(@procedure_id)
  end

  private

  def batch? = @dossier_id.nil?

  def modal_id
    batch? ? 'modal-archive-batch' : "modal-archive-#{@dossier_id}"
  end

  def checkbox_id
    "#{modal_id}-dismiss"
  end

  def form_id
    "#{modal_id}-form"
  end

  def form_options
    if batch?
      { url: instructeur_batch_operations_path(procedure_id: @procedure_id), method: :post, id: form_id, data: { turbo: true, 'batch-operation-target': 'archiveForm' } }
    else
      { url: archive_instructeur_dossier_path(@procedure_id, @dossier_id, statut: helpers.params[:statut]), method: :patch, id: form_id }
    end
  end
end
