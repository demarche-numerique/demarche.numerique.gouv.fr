# frozen_string_literal: true

module Events
  # A submission of public champs after the deposit, by the usager or an
  # instructeur. data: revision_id, checkpoint (the history stream holding
  # the replaced values)
  class DossierModifie < DossierEvent
  end
end
