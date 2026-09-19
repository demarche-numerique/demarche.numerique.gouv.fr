# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260918BackfillTypeDeChampProcedureIdTask do
    describe "#process" do
      subject(:process) { described_class.process(procedure) }

      let(:procedure) { procedures.individual }

      def type_de_champ_ids(procedure)
        ProcedureRevisionTypeDeChamp
          .unscope(:eager_load)
          .where(revision_id: procedure.revisions.select(:id))
          .distinct
          .pluck(:type_de_champ_id)
      end

      def procedure_ids(procedure)
        TypeDeChamp.where(id: type_de_champ_ids(procedure)).pluck(:procedure_id).uniq
      end

      # a type de champ of a past revision only, and one of the draft only
      before do
        procedure.draft_revision.remove_type_de_champ(procedure.draft_revision.public_root_type_de_champs.first.stable_id)
        procedure.publish_revision!(administrateurs.default)
        procedure.draft_revision.add_type_de_champ(type_champ: "text", libelle: "Dans le brouillon")

        TypeDeChamp.where(id: type_de_champ_ids(procedure)).update_all(procedure_id: nil)
      end

      it "attaches the types de champ of every revision to the procedure" do
        expect(type_de_champ_ids(procedure).size).to eq(7)
        expect { process }.to change { procedure_ids(procedure) }.from([nil]).to([procedure.id])
      end

      it "leaves the types de champ of the other procedures alone" do
        expect { process }.not_to change { procedure_ids(procedures.close) }
      end

      context "with a type de champ already attached" do
        let(:type_de_champ) { procedure.draft_revision.public_root_type_de_champs.first }

        before { type_de_champ.update_column(:procedure_id, procedures.close.id) }

        it "keeps it" do
          expect { process }.not_to change { type_de_champ.reload.procedure_id }
        end
      end

      context "with a type de champ laid out by another procedure too" do
        let(:type_de_champ) { procedure.draft_revision.public_root_type_de_champs.first }

        before do
          procedures.close.draft_revision.revision_type_de_champs.create!(type_de_champ:, position: 1)
        end

        it "leaves it to the task splitting them" do
          expect { process }.not_to change { type_de_champ.reload.procedure_id }.from(nil)
          expect(procedure_ids(procedure)).to contain_exactly(nil, procedure.id)
        end
      end
    end
  end
end
