# frozen_string_literal: true

module Events
  # A label removed from the dossier; the deletion of the label itself is
  # not recorded. data: label_id
  class DossierLabelSupprime < DossierEvent
  end
end
