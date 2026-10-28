# frozen_string_literal: true

module Events
  # Every reassignment after the deposit; the routings of a brouillon are not
  # recorded, dossier_depose carries the groupe. data: groupe_instructeur_id,
  # mode (DossierAssignment.modes)
  class DossierRoute < DossierEvent
  end
end
