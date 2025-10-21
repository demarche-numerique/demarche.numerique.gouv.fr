# frozen_string_literal: true

module Maintenance
  # Backfill identity_kind on existing procedures from the legacy for_individual flag.
  # Introduced alongside the identity_kind enum (individual/personne_morale/anonymous).
  # 2026-06-30
  class BackfillIdentityKindOnProceduresTask < MaintenanceTasks::Task
    def collection
      Procedure.with_discarded.where(identity_kind: nil)
    end

    def process(procedure)
      # `for_individual?` now reads identity_kind (still nil here), so read the legacy column directly.
      identity_kind = procedure.read_attribute(:for_individual) ? 'individual' : 'personne_morale'
      procedure.update_column(:identity_kind, identity_kind)
    end

    def count
      collection.count
    end
  end
end
