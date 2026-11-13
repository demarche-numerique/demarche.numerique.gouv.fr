# frozen_string_literal: true

# A procedure that requires FranceConnect+ opens its dossiers to a FranceConnect+ session only
module FranceConnectPlusRestrictionConcern
  extend ActiveSupport::Concern

  # Redirects, unless the current session may reach the dossier, or the procedure's dossiers.
  # The user comes back to the page once signed in with FranceConnect+: a page that can be
  # opened again, else the dossier.
  def ensure_france_connect_plus_for(dossier_or_procedure)
    dossier_or_procedure.bind_france_connect_plus!(Current.user_session) if dossier_or_procedure.is_a?(Dossier)
    return if !dossier_or_procedure.france_connect_plus_missing?(Current.user_session)

    if request.get? && request.format.html?
      store_location_for(:user, request.fullpath)
    elsif dossier_or_procedure.is_a?(Dossier)
      store_location_for(:user, dossier_path(dossier_or_procedure))
    end

    # A FranceConnect+ session of another identity than the dossier's would loop through FranceConnect+
    alert = Current.user_session&.via_france_connect_plus? ? 'another_identity' : 'procedure_required'
    redirect_to france_connect_plus_required_path, alert: t("errors.messages.france_connect_plus.#{alert}")
  end
end
