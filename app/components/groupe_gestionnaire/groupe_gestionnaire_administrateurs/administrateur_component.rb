# frozen_string_literal: true

class GroupeGestionnaire::GroupeGestionnaireAdministrateurs::AdministrateurComponent < ApplicationComponent
  include ApplicationHelper

  def initialize(groupe_gestionnaire:, administrateur:, is_gestionnaire: true)
    @groupe_gestionnaire = groupe_gestionnaire
    @administrateur = administrateur
    @is_gestionnaire = is_gestionnaire
  end

  def email
    if @administrateur.user_id == current_user&.id
      t(".c_est_vous", email: @administrateur.email)
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
    button_to t(".remove_from_group"),
      remove_gestionnaire_groupe_gestionnaire_administrateur_path(@groupe_gestionnaire, @administrateur),
      method: :delete,
      class: 'fr-btn fr-btn--sm fr-btn--tertiary',
      form: { data: { turbo: true, turbo_confirm: t(".remove_confirm", email: @administrateur.email, group_name: @groupe_gestionnaire.name) } }
  end

  def destroy_button
    button_to t(".revoke_admin_access"),
      gestionnaire_groupe_gestionnaire_administrateur_path(@groupe_gestionnaire, @administrateur),
      method: :delete,
      disabled: !@administrateur.can_be_deleted?,
      class: 'fr-btn fr-btn--sm fr-btn--tertiary',
      title: @administrateur.can_be_deleted? ? t(".delete") : t(".cannot_delete_admin"),
      form: { data: { turbo: true, turbo_confirm: t(".delete_confirm", email: @administrateur.email) } }
  end
end
