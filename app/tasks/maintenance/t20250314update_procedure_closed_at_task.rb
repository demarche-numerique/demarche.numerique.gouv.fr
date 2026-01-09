# frozen_string_literal: true

module Maintenance
  class T20250314updateProcedureClosedAtTask < MaintenanceTasks::Task
    # Documentation: cette tâche modifie la date de clôture d’une procédure.
    # Elle peut être utilisée en cas d’erreur de l’administrateur.
    # Le format de la date de clôture (closing_date) doit être "YYYY-MM-DD".

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    attribute :procedure_id, :string
    validates :procedure_id, presence: true
    attribute :closing_date, :string
    validates :closing_date, presence: true

    def collection
      [Procedure.find(procedure_id)]
    end

    def process(procedure)
      closed_at = Time.zone.parse(closing_date)
      procedure.update!(closed_at: closed_at)
    end
  end
end
