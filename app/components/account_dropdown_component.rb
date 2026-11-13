# frozen_string_literal: true

class AccountDropdownComponent < ViewComponent::Base
  PROFIL_CONTEXT_PROFILES = [:user, :instructeur, :administrateur, :expert, :gestionnaire].freeze

  attr_reader :dossier
  attr_reader :nav_bar_profile

  delegate :current_user, :current_email, :color_by_role, :multiple_devise_profile_connect?,
           :user_signed_in?, :instructeur_signed_in?, :expert_signed_in?,
           :administrateur_signed_in?, :gestionnaire_signed_in?, :super_admin_signed_in?,
           to: :helpers

  def initialize(dossier:, nav_bar_profile:)
    @dossier = dossier
    @nav_bar_profile = nav_bar_profile
  end

  def profil_path_params
    PROFIL_CONTEXT_PROFILES.include?(nav_bar_profile) ? { context: nav_bar_profile } : {}
  end

  def france_connected?
    current_user&.france_connected_with_one_identity?
  end

  def france_connected_plus? = Current.user_session&.via_france_connect_plus?

  def show_profile_badge?
    nav_bar_profile != :guest
  end

  def instructeur_path
    if controller_name == "procedures" && params[:id].present?
      instructeur_procedure_path(params[:id])
    elsif params[:procedure_id].present?
      instructeur_procedure_path(params[:procedure_id])
    else
      instructeur_procedures_path
    end
  end

  def admin_path
    if params[:procedure_id].present?
      admin_procedure_path(params[:procedure_id])
    else
      admin_procedures_path
    end
  end
end
