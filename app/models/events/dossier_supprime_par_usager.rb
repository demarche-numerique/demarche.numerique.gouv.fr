# frozen_string_literal: true

module Events
  # data: reason (DeletedDossier.reasons), hidden_from_administration (true
  # when this deletion took the dossier away from the administration)
  class DossierSupprimeParUsager < DossierEvent
  end
end
