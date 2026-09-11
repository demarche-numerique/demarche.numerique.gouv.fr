# frozen_string_literal: true

module Maintenance
  class T20250226FixDossiersEnInstructionWithPendingCorrectionTask < MaintenanceTasks::Task
    # Cette tâche traite les dossiers en instruction avec une correction en attente pour les repasser en construction.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    attribute :procedure_id, :string
    validates :procedure_id, presence: true

    def collection
      Procedure.find(procedure_id)
        .dossiers
        .state_en_instruction
        .with_pending_corrections
    end

    def process(dossier)
      Dossier.transaction do
        correction = dossier.pending_correction
        dossier.resolve_pending_correction

        if dossier.procedure.sva_svr_enabled?
          class << dossier.procedure
            def sva_svr_enabled?
              false # contourne guard can_repasser_en_construction?
            end
          end
        end

        dossier.repasser_en_construction!(instructeur: correction.commentaire.instructeur)

        correction.update!(resolved_at: nil)
      end
    rescue => e
      Rails.logger.error("Failed to process dossier #{dossier.id}: #{e.message}")
      Sentry.capture_exception(e, tags: { dossier: dossier.id })
    end
  end
end
