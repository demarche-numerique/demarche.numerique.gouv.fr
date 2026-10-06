# frozen_string_literal: true

class Instructeurs::ArchiveModalComponent < ApplicationComponent
  attr_reader :procedure

  def initialize(procedure: nil, batch: false)
    @procedure = procedure
    @batch = batch
  end

  def render?
    current_instructeur.present? && (procedure.nil? || !current_instructeur.archive_warning_dismissed_for?(procedure.id))
  end

  private

  def batch? = @batch

  def modal_id
    batch? ? 'modal-archive-batch' : 'modal-archive'
  end

  def title_id
    "#{modal_id}-title"
  end

  def checkbox_id
    "#{modal_id}-dismiss"
  end

  def form_options
    if batch?
      { url: instructeur_batch_operations_path(procedure_id: procedure.id), method: :post, data: { turbo: true, 'batch-operation-target': 'archiveForm' } }
    else
      { url: '', method: :patch, authenticity_token: helpers.form_authenticity_token }
    end
  end
end
