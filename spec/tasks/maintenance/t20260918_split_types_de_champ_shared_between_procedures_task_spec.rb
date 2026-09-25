# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260918SplitTypesDeChampSharedBetweenProceduresTask do
    describe "#process" do
      subject(:process) { described_class.process(procedure) }

      let(:original) { procedures.individual }
      let(:kopy) do
        original.clone(admin: administrateurs.default).tap do
          it.publish_or_reopen!(administrateurs.default, "demarche-demo-copie")
        end
      end

      def type_de_champ_ids(procedure)
        ProcedureRevisionTypeDeChamp
          .unscope(:eager_load)
          .where(revision_id: procedure.revisions.select(:id))
          .distinct
          .pluck(:type_de_champ_id)
      end

      def justificatif(procedure)
        ProcedureRevision.find(procedure.published_revision_id).type_de_champs.find(&:piece_justificative?)
      end

      def layout(revision)
        revision.revision_type_de_champs.reload.map { [it.position, it.parent_id, it.stable_id, it.libelle] }
      end

      # the defect: the coordinates of the copy hold the types de champ of the original
      before do
        justificatif(original).piece_justificative_template.attach(io: StringIO.new("modèle"), filename: "modele.txt")

        own_type_de_champ_ids = type_de_champ_ids(kopy)
        original_ids_by_stable_id = original.published_revision.type_de_champs.to_h { [it.stable_id, it.id] }

        TypeDeChamp.where(id: own_type_de_champ_ids).pluck(:id, :stable_id).each do |id, stable_id|
          ProcedureRevisionTypeDeChamp
            .unscope(:eager_load)
            .where(type_de_champ_id: id)
            .update_all(type_de_champ_id: original_ids_by_stable_id.fetch(stable_id))
        end
        TypeDeChamp.where(id: own_type_de_champ_ids).delete_all
        # the task ran before the revisions stored their tree: the types de champ
        # are laid out from the coordinates, as they were then
        ProcedureRevision.where(procedure_id: kopy.id).update_all(type_de_champ_tree: nil)
      end

      context "with the procedure holding the types de champ of an older one" do
        let(:procedure) { kopy }

        it "gives the procedure its own types de champ" do
          expect { process }.to change { type_de_champ_ids(kopy) & type_de_champ_ids(original) }
            .from(match_array(type_de_champ_ids(original))).to([])
        end

        it "keeps one type de champ per stable id across the revisions" do
          process

          expect(layout(kopy.draft_revision).size).to eq(6)
          expect(kopy.draft_revision.revision_type_de_champs.reload.map(&:type_de_champ_id))
            .to eq(kopy.published_revision.revision_type_de_champs.reload.map(&:type_de_champ_id))
        end

        it "keeps the layout and the attributes" do
          expect { process }.not_to change { [layout(kopy.draft_revision), layout(kopy.published_revision)] }
        end

        it "copies the attachments" do
          process

          expect(justificatif(kopy).piece_justificative_template).to be_attached
          expect(justificatif(kopy).piece_justificative_template.attachment)
            .not_to eq(justificatif(original).piece_justificative_template.attachment)
        end

        it "leaves the older procedure alone" do
          expect { process }.not_to change { [type_de_champ_ids(original).sort, layout(original.published_revision)] }
        end

        it "does nothing when run again" do
          process

          expect { described_class.process(kopy) }.not_to change { type_de_champ_ids(kopy).sort }
        end

        # the copy gets the highest id, which reads as the latest version of the champ
        context "when it has since published a newer version of a champ" do
          let(:stable_id) { original.published_revision.type_de_champs.find(&:text?).stable_id }
          let(:shared_type_de_champ_id) { original.published_revision.type_de_champs.find(&:text?).id }

          before do
            Procedure.find(kopy.id).draft_revision.find_and_ensure_exclusive_use(stable_id).update!(libelle: "nouveau libellé")
            Procedure.find(kopy.id).publish_revision!(administrateurs.default)
          end

          it "keeps the record and gives the copy to the older procedure" do
            expect { process }.to change { type_de_champ_ids(original).include?(shared_type_de_champ_id) }.from(true).to(false)

            expect(type_de_champ_ids(kopy)).to include(shared_type_de_champ_id)
            expect(type_de_champ_ids(kopy) & type_de_champ_ids(original)).to eq([])
          end

          it "keeps the newer version the latest one" do
            libelle = -> { Procedure.find(kopy.id).aggregated_type_de_champs.type_de_champ(stable_id).libelle }

            expect { process }.not_to change { libelle.call }.from("nouveau libellé")
          end

          it "keeps the layout and the attributes of the older procedure" do
            expect { process }.not_to change { layout(original.published_revision) }
          end

          it "raises when the older procedure has a newer version too" do
            Procedure.find(original.id).draft_revision.find_and_ensure_exclusive_use(stable_id).update!(libelle: "autre libellé")
            Procedure.find(original.id).publish_revision!(administrateurs.default)

            expect { process }.to raise_error(/#{shared_type_de_champ_id} has a newer version/)
              .and not_change { type_de_champ_ids(kopy).sort }
          end
        end
      end

      context "with the older procedure" do
        let(:procedure) { original }

        before { kopy }

        it "keeps its types de champ" do
          expect { process }.not_to change { type_de_champ_ids(original).sort }
        end
      end
    end
  end
end
