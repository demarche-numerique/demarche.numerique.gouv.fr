# frozen_string_literal: true

describe Columns::JSONPathColumn do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :address }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }
  let(:stable_id) { champ.stable_id }
  let(:tdc_type) { champ.last_write_type_champ }
  let(:column) { described_class.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type:, jsonpath:, displayable: true, mandatory: true) }

  describe '#value' do
    let(:jsonpath) { '$.city_name' }

    subject { column.value(champ) }

    context 'when champ has value_json' do
      before { champ.update(value_json: { city_name: 'Grenoble' }) }

      it { is_expected.to eq('Grenoble') }
    end

    context 'when champ has no value_json' do
      it { is_expected.to be_nil }
    end
  end

  describe '#filtered_ids' do
    context 'with regular search' do
      let(:jsonpath) { '$.city_name' }

      subject { column.filtered_ids(Dossier.all, { operator: 'match', value: ['reno', 'Lyon'] }) }

      context 'when champ has value_json' do
        before { champ.update(value_json: { city_name: 'Grenoble' }) }

        it { is_expected.to eq([dossier.id]) }
      end

      context 'when champ has no value_json' do
        it { is_expected.to eq([]) }
      end
    end

    context 'with a numeric jsonpath key (e.g. a referentiel column whose header is a number)' do
      let(:jsonpath) { '$.referentiel.data.row.4' }

      subject { column.filtered_ids(Dossier.all, { operator: 'match', value: ['Lyon'] }) }

      context 'when champ has value_json matching' do
        before { champ.update(value_json: { referentiel: { data: { row: { '4' => 'Lyon' } } } }) }

        it { is_expected.to eq([dossier.id]) }
      end

      context 'when champ has value_json not matching' do
        before { champ.update(value_json: { referentiel: { data: { row: { '4' => 'Paris' } } } }) }

        it { is_expected.to eq([]) }
      end
    end

    context 'with avanced search using special characters' do
      let(:jsonpath) { '$.city_name' }

      subject { column.filtered_ids(Dossier.all, { operator: 'match', value: ['*reno*', 'Lyon'] }) }

      context 'when champ has value_json we catch Invalid Regex error and return []' do
        before { champ.update(value_json: { city_name: 'Grenoble' }) }

        it { is_expected.to eq([]) }
      end

      context 'when champ has no value_json we catch Invalid Regex error and return []' do
        it { is_expected.to eq([]) }
      end
    end

    context 'with date range' do
      let(:jsonpath) { '$.issue_date' }
      let(:column) { described_class.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type:, jsonpath:, type: :date, displayable: true, mandatory: true) }
      let(:dossier_in_range)  { create(:dossier, procedure:) }
      let(:dossier_out_range) { create(:dossier, procedure:) }

      context 'bounded on both sides (this_year)' do
        before do
          dossier_in_range.champ_data.first.update(value_json: { issue_date: Date.current.iso8601 })
          dossier_out_range.champ_data.first.update(value_json: { issue_date: 5.years.ago.to_date.iso8601 })
        end

        subject { column.filtered_ids(Dossier.all, { operator: 'this_year' }) }

        it do
          is_expected.to include(dossier_in_range.id)
          is_expected.not_to include(dossier_out_range.id)
        end
      end

      context 'bounded only on the right (before operator)' do
        before do
          dossier_in_range.champ_data.first.update(value_json: { issue_date: '2020-06-15' })
          dossier_out_range.champ_data.first.update(value_json: { issue_date: '2022-06-15' })
        end

        subject { column.filtered_ids(Dossier.all, { operator: 'before', value: ['2021-01-01'] }) }

        it do
          is_expected.to include(dossier_in_range.id)
          is_expected.not_to include(dossier_out_range.id)
        end
      end

      context 'bounded only on the left (after operator)' do
        before do
          dossier_in_range.champ_data.first.update(value_json: { issue_date: '2022-06-15' })
          dossier_out_range.champ_data.first.update(value_json: { issue_date: '2020-06-15' })
        end

        subject { column.filtered_ids(Dossier.all, { operator: 'after', value: ['2021-01-01'] }) }

        it do
          is_expected.to include(dossier_in_range.id)
          is_expected.not_to include(dossier_out_range.id)
        end
      end

      context 'nil..nil range' do
        before do
          dossier_in_range.champ_data.first.update(value_json: { issue_date: '2022-06-15' })
          dossier_out_range.champ_data.first.update(value_json: { issue_date: '2020-06-15' })
        end

        subject { column.filtered_ids(Dossier.all, { operator: 'after', value: [nil] }) }

        it { is_expected.to include(dossier_in_range.id, dossier_out_range.id) }
      end
    end

    context 'with integer' do
      let(:jsonpath) { '$.issue_integer' }
      let(:column) { described_class.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type:, jsonpath:, type: :integer, displayable: true, mandatory: true) }
      let(:dossier_match) { create(:dossier, procedure:) }
      let(:dossier_no_match) { create(:dossier, procedure:) }

      before do
        dossier_match.champ_data.first.update(value_json: { issue_integer: 2000 })
        dossier_no_match.champ_data.first.update(value_json: { issue_integer: 2012 })
      end

      subject { column.filtered_ids(Dossier.all, { operator: 'match', value: }) }

      context 'with exact integer match' do
        let(:value) { ['2000'] }

        it do
          is_expected.to include(dossier_match.id)
          is_expected.not_to include(dossier_no_match.id)
        end
      end

      context 'with multiple integer values' do
        let(:value) { ['2000', '1234'] }

        it do
          is_expected.to include(dossier_match.id)
          is_expected.not_to include(dossier_no_match.id)
        end
      end

      context 'with non integer search term' do
        let(:value) { ['abc'] }

        it 'returns all dossiers (nothing filterable)' do
          is_expected.to include(dossier_match.id, dossier_no_match.id)
        end
      end

      context 'with mixed valid and invalid terms' do
        let(:value) { ['abc', '2000'] }

        it do
          is_expected.to include(dossier_match.id)
          is_expected.not_to include(dossier_no_match.id)
        end
      end
    end

    context 'with blank filter values' do
      let(:jsonpath) { '$.postal_code' }
      let(:dossier1) { create(:dossier, procedure:) }
      let(:dossier2) { create(:dossier, procedure:) }
      let(:dossier3) { create(:dossier, procedure:) }
      let(:dossiers) { Dossier.where(id: [dossier1.id, dossier2.id, dossier3.id]) }

      before do
        dossier1.champ_data.first.update(value_json: { postal_code: '60580' })
        dossier2.champ_data.first.update(value_json: { postal_code: '75001' })
      end

      context 'when filter value contains only blank strings' do
        subject { column.filtered_ids(dossiers, { operator: 'match', value: ['', '  ', nil] }) }

        it 'returns all dossiers without filtering' do
          is_expected.to contain_exactly(dossier1.id, dossier2.id, dossier3.id)
        end
      end
    end

    context "on a champ which requires the user to confirm the accuracy of the data (champs FC)" do
      let(:jsonpath) { '$.fc_data' }
      let(:column) { Columns::QuotientFamilialColumn.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type:, jsonpath:, type: :integer, displayable: true, mandatory: true) }
      let(:dossier_with_correct_data) { create(:dossier, procedure:) }
      let(:dossier_with_incorrect_data) { create(:dossier, procedure:) }

      before do
        dossier_with_correct_data.champ_data.first.update(value_json: { fc_data: 123 }, value: 'true')
        dossier_with_incorrect_data.champ_data.first.update(value_json: { fc_data: 123 }, value: 'false')
      end

      subject { column.filtered_ids(Dossier.all, { operator: 'match', value: ['123'] }) }

      it do
        is_expected.to include(dossier_with_correct_data.id)
        is_expected.not_to include(dossier_with_incorrect_data.id)
      end

      context do
        let(:column) { described_class.new(procedure_id: procedure.id, label: 'label', stable_id:, tdc_type:, jsonpath:, type: :integer, displayable: true, mandatory: true) }

        it 'has no effect on standard json path columns (to be sure)' do
          is_expected.to include(dossier_with_correct_data.id)
          is_expected.to include(dossier_with_incorrect_data.id)
        end
      end
    end
  end

  describe '#initializer' do
    let(:jsonpath) { %{$.'city_name} }

    it { expect(column.jsonpath).to eq(%{$.''city_name}) }
  end
end
