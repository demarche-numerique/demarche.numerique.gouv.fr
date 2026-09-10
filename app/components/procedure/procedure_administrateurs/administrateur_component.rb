# frozen_string_literal: true

class Procedure::ProcedureAdministrateurs::AdministrateurComponent < ApplicationComponent
  include ApplicationHelper

  def initialize(procedure:, administrateur:)
    @procedure = procedure
    @administrateur = administrateur
  end

  def email
    if @administrateur == current_administrateur
      "#{@administrateur.email} #{t('.its_you')}"
    else
      @administrateur.email
    end
  end

  def created_at
    I18n.l(@administrateur.created_at.to_date, format: :short)
  end

  def registration_state
    @administrateur.registration_state
  end

  def remove_button
    if is_there_at_least_another_active_admin?
      button_to t(".remove"),
       admin_procedure_administrateur_path(@procedure, @administrateur),
       method: :delete,
       class: 'fr-btn fr-btn--tertiary fr-btn--sm',
       form: { data: { turbo: true, turbo_confirm: t(".confirm_remove", email: @administrateur.email, libelle: @procedure.libelle) } }
    end
  end

  def is_there_at_least_another_active_admin?
    if @administrateur.active?
      @procedure.administrateurs.count(&:active?) > 1
    else
      @procedure.administrateurs.count(&:active?) >= 1
    end
  end
end
