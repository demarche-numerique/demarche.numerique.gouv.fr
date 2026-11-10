# frozen_string_literal: true

# Fabrique la source de préremplissage de l'identité pour la requête courante,
# pour les contrôleurs et les vues qui rendent l'étape identité.
module IdentityPrefillConcern
  extend ActiveSupport::Concern

  included do
    helper_method :identity_prefill_source
  end

  def identity_prefill_source(dossier)
    IdentityPrefillSource.new(dossier:, source: current_identity_provider)
  end

  # Le fournisseur d'identité que cette requête privilégie. Seul ProConnect
  # dépend de la session : FranceConnect est résolu depuis l'identité persistée.
  def current_identity_provider
    Current.user_session.via_pro_connect? ? :pro_connect : :france_connect
  end
end
