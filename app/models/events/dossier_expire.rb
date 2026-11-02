# frozen_string_literal: true

module Events
  # An automatic deletion at the end of the retention period.
  # data: reason (DeletedDossier.reasons), hidden_from_administration (true
  # when this deletion took the dossier away from the administration)
  class DossierExpire < DossierEvent
  end
end
