# frozen_string_literal: true

describe ProcedurePresentation do
  describe "#type_de_champs_for_procedure_export" do
    subject { procedure.type_de_champs_for_procedure_export.pluck(:libelle) }

    context 'for a draft procedure' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :number, libelle: 'libelle 1' }]) }

      context 'when there are one tdc on a draft revision' do
        it { is_expected.to match(['libelle 1']) }
      end
    end

    context 'for a published procedure' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: []) }
      let!(:tdc) { procedure.draft_revision.add_type_de_champ({ type: TypesDeChamp::Number.name, libelle: 'libelle 1' }) }

      before do
        procedure.publish_revision!(procedure.administrateurs.first)
      end

      it { is_expected.to match(['libelle 1']) }

      context 'when there is another published revision with an added tdc' do
        let(:added_tdc) { { type: TypesDeChamp::Number.name, libelle: 'libelle 2', after_stable_id: tdc.stable_id } }

        before do
          procedure.draft_revision.add_type_de_champ(added_tdc)
          procedure.publish_revision!(procedure.administrateurs.first)
        end

        it { is_expected.to match(['libelle 1', 'libelle 2']) }
      end

      context 'add one tdc above the first one' do
        let(:tdc0) { { type: TypesDeChamp::Number.name, libelle: 'libelle 0' } }

        before do
          created_tdc0 = procedure.draft_revision.add_type_de_champ(tdc0)
          procedure.draft_revision.reload.move_type_de_champ(created_tdc0.stable_id, 0)
          procedure.publish_revision!(procedure.administrateurs.first)
        end

        it { is_expected.to match(['libelle 0', 'libelle 1']) }

        context 'and finally, when this tdc is removed' do
          let!(:previous_tdc0) { procedure.published_revision.public_root_type_de_champs.find { _1.libelle == 'libelle 0' } }

          before do
            procedure.draft_revision.remove_type_de_champ(previous_tdc0.stable_id)

            procedure.publish_revision!(procedure.administrateurs.first)
          end

          it { is_expected.to match(['libelle 1', 'libelle 0']) }
        end
      end

      context 'when there is another published revision with a renamed tdc' do
        let!(:previous_tdc) { procedure.published_revision.public_root_type_de_champs.first }
        let!(:changed_tdc) { { type: TypesDeChamp::Number.name, libelle: 'changed libelle 1' } }

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
