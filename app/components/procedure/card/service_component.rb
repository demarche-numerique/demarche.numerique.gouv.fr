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
      { label: t('.badge.validated'), variant: :success }
    else
      { label: t('.badge.todo'), variant: :warning }
    end
  end

  def service_button_text
    if @procedure.service.present?
      t('.action.edit')
    elsif @administrateur.services.present?
      t('.action.choose')
    else
      t('.action.fill')
    end
  end
end
