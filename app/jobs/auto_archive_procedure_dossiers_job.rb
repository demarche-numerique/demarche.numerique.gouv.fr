# frozen_string_literal: true

class AutoArchiveProcedureDossiersJob < ApplicationJob
  def perform(procedure)
    procedure
      .dossiers
      .state_en_construction
      .find_each do |d|
        next unless d.may_passer_automatiquement_en_instruction?

        begin
          d.passer_automatiquement_en_instruction!
        rescue StandardError => e
          Sentry.capture_exception(e, tags: { dossier: d.id })
        end
      end
  end
end
