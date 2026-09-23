# frozen_string_literal: true

class Procedure::Card::DossierSubmittedMessageComponent < ApplicationComponent
  def initialize(procedure:)
    @procedure = procedure
  end

  private

  def badge
    if @procedure.active_dossier_submitted_message.present?
      { label: 'Validé', variant: :success }
    else
      { label: 'À configurer', variant: :info }
    end
  end
end
