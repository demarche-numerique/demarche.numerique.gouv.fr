# frozen_string_literal: true

module Maintenance
  class T20260317FixProcedurePathsEndingWithTrailingSeparatorTask < MaintenanceTasks::Task
    # Find all procedure_paths whose path ends with a hyphen or underscore,
    # and for each one that is the canonical path of its procedure, add a new
    # path with the trailing separator(s) removed (if the resulting path is available).
    def collection
      ProcedurePath.where("path ~ '[-_]$'")
    end

    def process(procedure_path)
      procedure = procedure_path.procedure

      return if procedure.nil?

      # Only act on the canonical (current) path
      return unless procedure_path.path == procedure.canonical_path

      new_path = procedure_path.path.sub(/[-_]+\z/, '')

      # Guard: resulting path must satisfy the minimum length requirement
      return if new_path.length < 3

      # Skip if this procedure already has that path
      return if procedure.procedure_paths.exists?(path: new_path)

      # Skip if another procedure already uses that path
      return unless procedure.path_available?(new_path)

      ProcedurePath.create!(procedure:, path: new_path)
    end
  end
end
