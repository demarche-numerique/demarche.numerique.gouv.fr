# frozen_string_literal: true

describe Columns::LinkedDropDownColumn do
  describe '#filtered_ids' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :linked_drop_down_list, libelle: 'linked' }]) }
    let(:type_de_champ) { procedure.active_revision.types_de_champ_public.first }
    let(:kept_dossier) { create(:dossier, procedure: procedure) }
    let(:discarded_dossier) { create(:dossier, procedure: procedure) }

    subject { column.filtered_ids(Dossier.all, { operator: 'match', value: search_terms }) }

    context "when search_terms is an empty string" do
      let(:column) { procedure.find_column(label: 'linked') }
      let(:search_terms) { [''] }

      it { expect { subject }.not_to raise_error }
    end

    context "when filter value is nil" do
      let(:column) { procedure.find_column(label: 'linked') }
      let(:search_terms) { nil }
      before { kept_dossier; discarded_dossier }

      it { is_expected.to match_array([kept_dossier.id, discarded_dossier.id]) }
    end

    context "when filter value is missing" do
      let(:column) { procedure.find_column(label: 'linked') }
      subject { column.filtered_ids(Dossier.all, { operator: 'match' }) }
      before { kept_dossier; discarded_dossier }

      it { is_expected.to match_array([kept_dossier.id, discarded_dossier.id]) }
    end

    context 'when path is :value' do
      let(:column) { procedure.find_column(label: 'linked') }

      before do
        kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id)
          .update(value: %{["section 1","option A"]})

        discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id)
          .update(value: %{["section 1","option B"]})
      end

      describe 'when looking for a part' do
        let(:search_terms) { ['option A'] }

        it { is_expected.to eq([kept_dossier.id]) }
      end

      describe 'when looking for the aggregated value' do
        let(:search_terms) { ['section 1  /  option A'] }

        it { is_expected.to match_array([kept_dossier.id]) }
      end
      describe 'when value is malformed' do
        let(:search_terms) { ['section 1  /'] }

        it { expect { subject }.not_to raise_error }
      end

      describe 'when looking for the aggregated value or a common value' do
        let(:search_terms) { ['section 1  /  option A', 'section'] }

        it { is_expected.to match_array([kept_dossier.id, discarded_dossier.id]) }
      end

      describe 'when looking for a shared string' do
        let(:search_terms) { ['option'] }

        it { is_expected.to match_array([kept_dossier.id, discarded_dossier.id]) }
      end
    end

    context 'when path is not :value' do
      before do
        kept_dossier.champs.find_by(stable_id: type_de_champ.stable_id)
          .update(value: %{["1","2"]})

        discarded_dossier.champs.find_by(stable_id: type_de_champ.stable_id)
          .update(value: %{["2","1"]})
      end

      context 'when path is :primary' do
        let(:column) { procedure.find_column(label: 'linked (Primaire)') }

        describe 'when looking kept part' do
          let(:search_terms) { ['1'] }

          it { is_expected.to eq([kept_dossier.id]) }
        end
      end

      context 'when path is :secondary' do
        let(:column) { procedure.find_column(label: 'linked (Secondaire)') }

        describe 'when looking kept part' do
          let(:search_terms) { ['2'] }

          it { is_expected.to eq([kept_dossier.id]) }
        end
      end
    end
  end

  describe '#options_for_select' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :linked_drop_down_list, libelle: 'linked', drop_down_options: ['--section 1--', 'option A', 'option B', '--section 2--', 'option C'] },
      ])
    end

    it 'normalizes the primary options as [label, value] pairs' do
      column = procedure.find_column(label: 'linked (Primaire)')

      expect(column.options_for_select).to eq([['section 1', 'section 1'], ['section 2', 'section 2']])
    end

    it 'normalizes the secondary options as [label, value] pairs' do
      column = procedure.find_column(label: 'linked (Secondaire)')

      expect(column.options_for_select).to eq([['option A', 'option A'], ['option B', 'option B'], ['option C', 'option C']])
    end
  end

  describe 'unpack_values' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :linked_drop_down_list, libelle: 'linked' }]) }
    let(:type_de_champ) { procedure.active_revision.types_de_champ_public.first }
    let(:column) { procedure.find_column(label: 'linked') }
    subject { column.send(:unpack_values, nil) }

    context 'when value is nil' do
      it { is_expected.to eq([]) }
    end
  end
end
