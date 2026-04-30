# frozen_string_literal: true

class Dossiers::BatchAlertComponent < ApplicationComponent
  attr_reader :batch

  def initialize(batch:, procedure:)
    @batch = batch
    @procedure = procedure

    @finished_unseen = @batch.finished_unseen?
    @batch.seen! if @finished_unseen
  end

  def should_refresh?
    !@batch.finished_at? || @finished_unseen
  end

  def procedure_path
    instructeur_procedure_path(@procedure, statut: params[:statut])
  end
end
