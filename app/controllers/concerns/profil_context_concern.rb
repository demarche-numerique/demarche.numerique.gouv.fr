# frozen_string_literal: true

# Les pages du profil sont atteignables depuis tous les espaces. Le paramètre
# `context` préserve la barre de navigation de l'espace d'origine.
#
# Surcharge le `nav_bar_profile` vide de NavBarProfileConcern, qui fournit par
# ailleurs le repli utilisé ici (`fallback_nav_bar_profile`).
module ProfilContextConcern
  extend ActiveSupport::Concern

  ALLOWED_NAV_BAR_PROFILES = [:user, :instructeur, :administrateur, :expert, :gestionnaire].freeze

  # Doit rester publique : _header.haml et _breadcrumbs.html.erb l'appellent
  # via controller.try(:nav_bar_profile).
  def nav_bar_profile
    context = params[:context]&.to_sym
    return context if ALLOWED_NAV_BAR_PROFILES.include?(context)
    fallback_nav_bar_profile.presence || :user
  end
end
