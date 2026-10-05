# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261005backfillProcedureTagsFromLegacyTask do
    let(:task) { described_class.new }
    let(:create_procedure_tags_task_ran_at) { Time.zone.parse('2024-10-15 09:56') }

    before do
      stub_const("#{described_class}::NEW_TAGS", ["Sport", "Mer"])
      stub_const("#{described_class}::MAPPING", {
        "éducation" => ["Education"],
        "jop" => ["Sport"],
        "sport" => ["Sport"],
        "scolaire" => ["Scolaire"],
        "candidature" => ["Candidature"],
      })
      ["Education", "Scolaire", "Candidature"].each { ProcedureTag.create!(name: it) }
      MaintenanceTasks::Run.new(task_name: "Maintenance::CreateProcedureTagsTask", status: :succeeded, started_at: create_procedure_tags_task_ran_at)
        .save!(validate: false)
    end

    def process_with_legacy_tags(procedure, legacy_tags)
      Procedure.with_discarded.where(id: procedure.id).update_all(["tags = ARRAY[?]::text[]", legacy_tags])
      task.process(task.collection.find(procedure.id))
    end

    it "links the tags the legacy values map to, even on a discarded procedure, creating only the new tags it needs" do
      procedure = procedures.brouillon
      Procedure.where(id: procedure.id).update_all(hidden_at: Time.zone.now)

      expect {
        2.times { process_with_legacy_tags(procedure, ['Éducation ', 'jop', 'scolaire', 'Inconnue', '']) }
      }.not_to change { Procedure.with_discarded.find(procedure.id).updated_at }
      expect(procedure.procedure_tags.reload.map(&:name)).to contain_exactly('Education', 'Sport', 'Scolaire')
      expect(ProcedureTag.where(name: 'Mer')).to be_empty
    end

    context "on a procedure older than CreateProcedureTagsTask" do
      let(:procedure) { procedures.individual }

      before { procedure.update_columns(created_at: create_procedure_tags_task_ran_at - 1.day) }

      it "does not link back a tag of its list that a legacy value names as that task matched it: an admin removed it" do
        process_with_legacy_tags(procedure, ['Scolaire', 'sport', 'candidature '])

        expect(procedure.procedure_tags.reload.map(&:name)).to contain_exactly('Sport', 'Candidature')
      end

      it "links such a tag on an instance where that task never ran" do
        MaintenanceTasks::Run.where(task_name: "Maintenance::CreateProcedureTagsTask").delete_all
        process_with_legacy_tags(procedure, ['scolaire'])

        expect(procedure.procedure_tags.reload.map(&:name)).to contain_exactly('Scolaire')
      end
    end
  end
end
