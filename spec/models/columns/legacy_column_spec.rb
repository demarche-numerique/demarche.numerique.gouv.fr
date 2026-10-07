# frozen_string_literal: true

describe Columns::LegacyColumn do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :checkbox, libelle: 'Case', stable_id: 1 }, { type: :integer_number, libelle: 'Nombre', stable_id: 2 }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:checkbox) { procedure.active_revision.type_de_champs.find(&:checkbox?) }
  let(:integer_number) { procedure.active_revision.type_de_champs.find(&:integer_number?) }
  let(:column) { checkbox.legacy_export_columns(procedure_id: procedure.id).first.second }
  let(:champ) { dossier.champ_data.find(&:checkbox?) }

  it 'is a champ column outside the catalogue' do
    expect(column).to be_champ_column
    expect(column).to have_attributes(stable_id: 1, label: 'Case', column_id: 'legacy/type_de_champ/1/Case')
    expect(procedure.columns).not_to include(column)
  end

  describe '#value' do
    it 'transforms the catalogue value' do
      champ.update(value: 'true')
      expect(column.value(champ)).to eq('on')

      champ.update(value: 'false')
      expect(column.value(champ)).to eq('off')
    end

    it 'gives the historical default for a blank champ' do
      expect(column.value(nil)).to eq('off')
      expect(integer_number.legacy_export_columns(procedure_id: procedure.id).first.second.value(nil)).to eq(0)
    end
  end

  context 'over a dossier column' do
    let(:dossier) { dossiers.en_construction }
    let(:base) { Columns::DossierColumn.new(procedure_id: dossier.procedure.id, table: 'self', column: 'id', label: 'ID') }
    let(:column) { described_class.new(procedure_id: dossier.procedure.id, columns: base, label: 'ID', &:to_s) }

    it 'is a dossier column' do
      expect(column).to be_dossier_column
      expect(column.value(dossier)).to eq(dossier.id.to_s)
    end
  end
end
