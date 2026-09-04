# frozen_string_literal: true

conditionable_types = [
  :checkbox,
  :yes_no,
  :integer_number,
  :decimal_number,
  :drop_down_list,
  :multiple_drop_down_list,
  :pre_rempli,
  :communes,
  :epci,
  :departements,
  :regions,
  :pays,
  :address,
]

describe 'an unanswered champ triggers no operator' do
  include Logic

  def computed_on_every_column(champ, procedure)
    champ.type_de_champ.columns(procedure_id: procedure.id).to_h do |column|
      [column.column_id, Logic::ChampColumnValue.new(column.stable_id, column.column_id).compute([champ])]
    end
  end

  conditionable_types.each do |type_champ|
    context "on a blank #{type_champ}" do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: type_champ }]) }
      let(:dossier) { create(:dossier, procedure:) }
      let(:champ) { dossier.champ_data.first }
      # A checkbox has no empty state: untouched, it answers « Non ».
      let(:expected) { type_champ == :checkbox ? false : nil }

      it 'computes nothing on Logic::ChampValue' do
        expect(champ_value(champ.stable_id).compute([champ])).to eq(expected)
      end

      it 'computes nothing on Logic::ChampColumnValue, whichever column' do
        computed_on_every_column(champ, procedure).each do |column_id, computed|
          expect(computed).to(eq(expected).or(be_nil), "#{column_id} computed #{computed.inspect}")
        end
      end
    end
  end

  context 'on a blank multiple_drop_down_list in advanced mode, whose columns read value_json' do
    let(:referentiel) { create(:csv_referentiel, :with_items) }
    let(:procedure) do
      create(:procedure, public_type_de_champs: [{ type: :multiple_drop_down_list, referentiel:, drop_down_mode: 'advanced' }])
    end
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }

    it 'computes nil rather than the empty join of its JSON path' do
      expect(computed_on_every_column(champ, procedure).values).to all(be_nil)
    end
  end

  context 'on a half-filled champ the type still reports as unanswered' do
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:column) { champ.type_de_champ.canonical_column(procedure_id: procedure.id) }

    subject do
      [
        champ_value(champ.stable_id).compute([champ]),
        Logic::ChampColumnValue.new(column.stable_id, column.column_id).compute([champ]),
      ]
    end

    context 'an address typed in free text, never resolved against the BAN' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :address }]) }

      before { champ.update_column(:value, '12 rue de la Paix') }

      it { is_expected.to eq([nil, nil]) }
    end

    context 'a multiple_drop_down_list holding an empty JSON array' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :multiple_drop_down_list }]) }

      before { champ.update_column(:value, '[]') }

      it { is_expected.to eq([nil, nil]) }
    end

    context 'a yes_no left as an empty string' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :yes_no }]) }

      before { champ.update_column(:value, '') }

      it { is_expected.to eq([nil, nil]) }
    end
  end

  context 'on a drop_down_list set to « Autre » with no text, which is an answer' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :drop_down_list, drop_down_other: true }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:column) { champ.type_de_champ.canonical_column(procedure_id: procedure.id) }

    before { champ.update!(value: Champs::DropDownListChamp::OTHER) }

    it 'computes OTHER on both terms' do
      expect(champ_value(champ.stable_id).compute([champ])).to eq(Champs::DropDownListChamp::OTHER)
      expect(Logic::ChampColumnValue.new(column.stable_id, column.column_id).compute([champ]))
        .to eq(Champs::DropDownListChamp::OTHER)
    end
  end
end
