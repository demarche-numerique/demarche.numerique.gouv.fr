# frozen_string_literal: true

describe ExportedColumn do
  describe '#libelle_with_value' do
    let(:column) do
      Columns::JSONPathColumn.new(
        procedure_id: 1,
        stable_id: 17,
        tdc_type: 'communes',
        label: 'Commune – Département',
        jsonpath: '$.department_code',
        displayable: true,
        type: :enum,
        options_for_select: [['60 – Oise', '60']],
        mandatory: false
      )
    end
    let(:champ) { instance_double(Champs::CommuneChamp) }

    before { allow(column).to receive(:value).with(champ).and_return('60') }

    it 'exports the label of an enum' do
      expect(described_class.new(column:, libelle: 'Département').libelle_with_value(champ, format: :csv))
        .to eq(['Département', '60 – Oise', :string])
    end

    it 'exports the bare value when raw' do
      expect(described_class.new(column:, libelle: 'Département', raw: true).libelle_with_value(champ, format: :csv))
        .to eq(['Département', '60', :string])
    end
  end
end
