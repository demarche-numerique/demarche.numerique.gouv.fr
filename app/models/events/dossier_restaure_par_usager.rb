# frozen_string_literal: true

module Events
  # data: reason (the hide reason being reversed), restored_to_administration
  # (true when the dossier becomes visible by the administration again)
  class DossierRestaureParUsager < DossierEvent
  end
end
