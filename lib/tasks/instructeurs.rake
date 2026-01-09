# frozen_string_literal: true

require Rails.root.join("lib", "tasks", "task_helper")

namespace :instructeurs do
  desc <<~EOD
    Import several instructeurs for a procedure
    rails instructeurs:import\[procedure_id,csv_path\]
  EOD
  task :import, [:procedure_id, :csv] => :environment do |_t, args|
    procedure_id = args[:procedure_id]
    csv = args[:csv]
    lines = CSV.readlines(csv, headers: true)

    rake_puts "Import en cours..."

    errors =
      InstructeursImportService.new.import(Procedure.find(procedure_id), lines)

    if errors.present?
      rake_puts "Ces instructeurs n’ont pas pu être importés :"
      rake_puts errors
    end

    rake_puts "Import terminé"
  end
end
