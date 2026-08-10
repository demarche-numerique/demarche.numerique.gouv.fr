# frozen_string_literal: true

describe ProcedurePresentation do
  describe "#types_de_champ_for_procedure_export" do
    subject { procedure.types_de_champ_for_procedure_export.pluck(:libelle) }

    context 'for a draft procedure' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :number, libelle: 'libelle 1' }]) }

      context 'when there are one tdc on a draft revision' do
        it { is_expected.to match(['libelle 1']) }
      end
    end

    context 'for a published procedure' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: []) }
      let!(:tdc) { procedure.draft_revision.add_type_de_champ({ type_champ: :number, libelle: 'libelle 1' }) }

      before do
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { is_expected.to match(['libelle 1']) }

      context 'when there is another published revision with an added tdc' do
        let(:added_tdc) { { type_champ: :number, libelle: 'libelle 2', after_stable_id: tdc.stable_id } }

        before do
          procedure.draft_revision.add_type_de_champ(added_tdc)
          procedure.publish_revision!(procedure.administrateurs.first)
        end

        it { is_expected.to match(['libelle 1', 'libelle 2']) }
      end

      context 'add one tdc above the first one' do
        let(:tdc0) { { type_champ: :number, libelle: 'libelle 0' } }

        before do
          created_tdc0 = procedure.draft_revision.add_type_de_champ(tdc0)
          procedure.draft_revision.reload.move_type_de_champ(created_tdc0.stable_id, 0)
          procedure.publish_revision!(procedure.administrateurs.first)
        end

        it { is_expected.to match(['libelle 0', 'libelle 1']) }

        context 'and finally, when this tdc is removed' do
          let!(:previous_tdc0) { procedure.published_revision.root_public_types_de_champ.find { _1.libelle == 'libelle 0' } }

          before do
            procedure.draft_revision.remove_type_de_champ(previous_tdc0.stable_id)

            procedure.publish_revision!(procedure.administrateurs.first)
          end

          it { is_expected.to match(['libelle 1', 'libelle 0']) }
        end
      end

      context 'when there is another published revision with a renamed tdc' do
        let!(:previous_tdc) { procedure.published_revision.root_public_types_de_champ.first }
        let!(:changed_tdc) { { type_champ: :number, libelle: 'changed libelle 1' } }

        before do
          type_de_champ = procedure.draft_revision.find_and_ensure_exclusive_use(previous_tdc.id)
          type_de_champ.update(changed_tdc)

          procedure.publish_revision!(procedure.administrateurs.first)
        end

        it { is_expected.to match(['changed libelle 1']) }
      end
    end
  end
end
