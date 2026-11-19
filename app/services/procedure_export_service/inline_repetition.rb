# frozen_string_literal: true

#   InlineRepetition.new(
#     max_rows: 3,
#     columns_by_child: {
#       <TypeDeChamp "Prénom"> => [<ExportedColumn "(Bloc répétable Enfants) – Prénom">],
#       <TypeDeChamp "Âge"> => [<ExportedColumn "(Bloc répétable Enfants) – Âge">],
#     }
#   )
ProcedureExportService::InlineRepetition = Data.define(:max_rows, :columns_by_child)
