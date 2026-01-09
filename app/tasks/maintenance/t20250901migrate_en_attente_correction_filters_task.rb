# frozen_string_literal: true

module Maintenance
  class T20250901migrateEnAttenteCorrectionFiltersTask < MaintenanceTasks::Task
    # Documentation: cette tâche migre les filtres sur l’ Etat du dossier avec la valeur pending_correction vers le filtre notification équivalent

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    run_on_first_deploy

    STATE_FILTERS = [
      :tous_filters,
      :suivis_filters,
      :traites_filters,
      :a_suivre_filters,
      :archives_filters,
      :expirant_filters,
      :supprimes_filters,
      :supprimes_recemment_filters,
    ].freeze

    def collection
      ProcedurePresentation.includes(assign_to: :procedure)
    end

    def process(pp)
      pp_changed = false

      STATE_FILTERS.each do |state_filter|
        current_state_filters = pp.send(state_filter)
        next unless current_state_filters.any? { is_en_attente_correction_legacy_filter(_1) }

        new_state_filters = current_state_filters.map do |filter|
          if is_en_attente_correction_legacy_filter(filter)
            pp_changed = true
            FilteredColumn.new(
              column: pp.procedure.dossier_notifications_column,
              filter: "attente_correction"
            )
          else
            filter
          end
        end

        pp.send("#{state_filter}=", new_state_filters)
      # a column can be not found for various reasons (deleted tdc, changed type, etc)
      # in this case we just ignore the error and continue
      rescue ActiveRecord::RecordNotFound
      end

      pp.save! if pp_changed
    end

    def is_en_attente_correction_legacy_filter(filter)
      filter.column.table == 'self' &&
      filter.column.column == 'state' &&
      (filter.filter == "pending_correction")
    end
  end
end
