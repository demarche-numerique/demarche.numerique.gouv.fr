# frozen_string_literal: true

# Migrate ProcedurePresentation references to the legacy commune-specific
# columns ($.code_postal, $.code_departement) over to the canonical
# AddressableColumnConcern jsonpaths ($.postal_code, $.department_code).
# Once all instances are migrated, the legacy_columns method in
# TypesDeChamp::Commune can be removed.
module Maintenance
  class T20260504MigrateLegacyCommuneColumnsInProcedurePresentationTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    LEGACY_TO_NEW_SUFFIX = {
      '-$.code_postal' => '-$.postal_code',
      '-$.code_departement' => '-$.department_code',
    }.freeze

    def collection
      ProcedurePresentation.where(<<~SQL.squish, p1: "%-$.code_postal%", p2: "%-$.code_departement%")
        displayed_columns::text LIKE :p1 OR displayed_columns::text LIKE :p2
        OR a_suivre_filters::text LIKE :p1 OR a_suivre_filters::text LIKE :p2
        OR suivis_filters::text LIKE :p1 OR suivis_filters::text LIKE :p2
        OR traites_filters::text LIKE :p1 OR traites_filters::text LIKE :p2
        OR tous_filters::text LIKE :p1 OR tous_filters::text LIKE :p2
        OR supprimes_filters::text LIKE :p1 OR supprimes_filters::text LIKE :p2
        OR supprimes_recemment_filters::text LIKE :p1 OR supprimes_recemment_filters::text LIKE :p2
        OR expirant_filters::text LIKE :p1 OR expirant_filters::text LIKE :p2
        OR archives_filters::text LIKE :p1 OR archives_filters::text LIKE :p2
      SQL
    end

    def process(presentation)
      migrate_displayed_columns(presentation)
      ProcedurePresentation::ALL_FILTERS.each { migrate_filters(presentation, _1) }

      presentation.save(validate: false) if presentation.changed?

    # a column can fail to resolve for various reasons (deleted tdc, etc.)
    rescue ActiveRecord::RecordNotFound
    end

    private

    def migrate_displayed_columns(presentation)
      original = presentation.displayed_columns
      migrated = original.map { swap_to_new(_1) || _1 }.uniq(&:h_id)
      presentation.displayed_columns = migrated if migrated != original
    end

    def migrate_filters(presentation, attr)
      original = presentation.send(attr)
      migrated = original.map do |fc|
        new_column = swap_to_new(fc.column)
        new_column ? FilteredColumn.new(column: new_column, filter: fc.filter) : fc
      end
      presentation[attr] = migrated if migrated != original
    end

    def swap_to_new(column)
      legacy_suffix = legacy_suffix_of(column)
      return nil unless legacy_suffix

      new_column_id = column.h_id[:column_id].delete_suffix(legacy_suffix) + LEGACY_TO_NEW_SUFFIX.fetch(legacy_suffix)
      Column.find(procedure_id: column.h_id[:procedure_id], column_id: new_column_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def legacy_suffix_of(column)
      return nil unless column.is_a?(Columns::JSONPathColumn)
      LEGACY_TO_NEW_SUFFIX.keys.find { |suffix| column.h_id[:column_id].end_with?(suffix) }
    end
  end
end
