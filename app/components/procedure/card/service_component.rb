# frozen_string_literal: true

class Procedure::Card::ServiceComponent < ApplicationComponent
  def initialize(procedure:, administrateur:)
    @procedure = procedure
    @administrateur = administrateur
  end

  private

  def service_link
    if @procedure.service.present?
      edit_admin_service_path(@procedure.service, procedure_id: @procedure.id)
    elsif @administrateur.services.present?
      admin_services_path(procedure_id: @procedure.id)
    else
      new_admin_service_path(procedure_id: @procedure.id)
    end
  end

  def badge
    if @procedure.service_id.present?
      { label: 'Validé', variant: :success }
    else
      { label: 'À faire', variant: :warning }
    end
  end

  def service_button_text
    if @procedure.service.present?
      'Modifier'
    elsif @administrateur.services.present?
      'Choisir'
    else
      'Remplir'
    end
  end
end
