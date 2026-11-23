# frozen_string_literal: true

class Procedure::ProcedureAdministrateurs::AdministrateurComponent < ApplicationComponent
  include ApplicationHelper

  def initialize(procedure:, administrateur:, api_tokens_by_administrator:)
    @procedure = procedure
    @administrateur = administrateur
    @api_tokens = api_tokens_by_administrator.fetch(administrateur.id, [])
  end

  def api_token_descriptions
    @api_tokens.map do |api_token|
      name = api_token.name
      last_use = api_token.last_used_at ? t('.used_ago', time: time_ago_in_words(api_token.last_used_at)) : t('.never_used')

      case [api_token.write_access?, api_token.full_access? || api_token.follows_clones?]
      in [true, true] then t('.api_token_writing_following_clones', name:, last_use:)
      in [true, false] then t('.api_token_writing', name:, last_use:)
      in [false, true] then t('.api_token_following_clones', name:, last_use:)
      in [false, false] then t('.api_token', name:, last_use:)
      end
    end
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
