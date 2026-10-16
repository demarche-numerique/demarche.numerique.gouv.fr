# frozen_string_literal: true

module Events
  # data: revision_id (the revision the dossier was submitted on),
  # groupe_instructeur_id (the groupe the brouillon was routed to; a
  # reassignment by the routing at the deposit records its own dossier_route)
  class DossierDepose < DossierEvent
  end
end
