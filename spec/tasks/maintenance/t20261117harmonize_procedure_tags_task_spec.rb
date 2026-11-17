# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261117harmonizeProcedureTagsTask do
    describe "#process" do
      subject(:process) { described_class.new.process(name) }

      let(:procedure) { procedures.individual }
      let(:other_procedure) { procedures.brouillon }

      def tag_names(procedure) = procedure.reload.procedure_tags.map(&:name)

      context "when the tag merges into an existing one" do
        let(:name) { "Collège" }
        let!(:college) { ProcedureTag.create!(name: "Collège", procedures: [procedure, other_procedure]) }
        let!(:education) { ProcedureTag.create!(name: "Éducation", procedures: [procedure]) }

        it "moves its procedures to the target, once each, and deletes it" do
          process

          expect(tag_names(procedure)).to eq(["Éducation"])
          expect(tag_names(other_procedure)).to eq(["Éducation"])
          expect(ProcedureTag.exists?(college.id)).to be(false)
        end

        it "moves the discarded procedures too" do
          other_procedure.update_column(:hidden_at, Time.zone.now)

          process

          expect(Procedure.with_discarded.find(other_procedure.id).procedure_tags.map(&:name)).to eq(["Éducation"])
        end
      end

      context "when the tag splits into several tags" do
        let(:name) { "FPRNM" }
        let!(:fprnm) { ProcedureTag.create!(name: "FPRNM", procedures: [procedure]) }
        let!(:aide_financiere) { ProcedureTag.create!(name: "Aide financière") }

        context "when they all exist" do
          let!(:transition_ecologique) { ProcedureTag.create!(name: "Transition écologique") }

          it "links every target" do
            process

            expect(tag_names(procedure)).to contain_exactly("Transition écologique", "Aide financière")
            expect(ProcedureTag.exists?(fprnm.id)).to be(false)
          end
        end

        context "when one of them is missing" do
          it "raises without creating it nor touching the tag" do
            expect { process }.to raise_error(ActiveRecord::RecordNotFound)

            expect(ProcedureTag.exists?(name: "Transition écologique")).to be(false)
            expect(tag_names(procedure)).to eq(["FPRNM"])
          end
        end
      end

      context "when the tag is renamed" do
        let(:name) { "Permis" }
        let!(:permis) { ProcedureTag.create!(name: "Permis", procedures: [procedure]) }

        it "renames the tag" do
          process

          expect(permis.reload.name).to eq("Permis de conduire")
          expect(tag_names(procedure)).to eq(["Permis de conduire"])
        end
      end

      context "when the tag has no replacement" do
        let(:name) { "Cerfa" }
        let!(:cerfa) { ProcedureTag.create!(name: "Cerfa", procedures: [procedure]) }

        it "deletes it" do
          process

          expect(tag_names(procedure)).to be_empty
          expect(ProcedureTag.exists?(cerfa.id)).to be(false)
        end
      end

      context "when the tag does not exist" do
        let(:name) { "Drone" }

        it "does nothing" do
          expect { process }.not_to raise_error
        end
      end
    end
  end
end
