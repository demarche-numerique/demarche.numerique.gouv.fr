# frozen_string_literal: true

describe ExportedColumnType do
  let(:type) { ExportedColumnType.new }

  describe 'deserialize' do
    context 'when the referenced column no longer exists in the procedure' do
      let(:raw) do
        JSON.generate(id: { procedure_id: 1, column_id: 'type_de_champ/999' }, libelle: 'Removed')
      end

      before do
        allow(Column).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'returns nil instead of raising RecordNotFound' do
        expect { type.deserialize(raw) }.not_to raise_error
        expect(type.deserialize(raw)).to be_nil
      end
    end

    context 'with a column of a commune champ' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :communes, libelle: 'Commune', stable_id: 17 }]) }
      let(:stored) { JSON.generate(id: { procedure_id: procedure.id, column_id: }, libelle: 'Département') }

      context 'when it is the legacy department column' do
        let(:column_id) { 'type_de_champ/17-$.code_departement' }

        it 'resolves the canonical column and flags it raw' do
          expect(type.deserialize(stored)).to have_attributes(raw: true, column: have_attributes(jsonpath: '$.department_code'))
        end

        it 'stays raw once saved under the canonical id' do
          saved = type.serialize(type.deserialize(stored))

          expect(JSON.parse(saved).dig('id', 'column_id')).to eq('type_de_champ/17-$.department_code')
          expect(type.deserialize(saved).raw).to be(true)
        end
      end

      context 'when it is the canonical department column' do
        let(:column_id) { 'type_de_champ/17-$.department_code' }

        it 'is not raw and stores no flag' do
          exported_column = type.deserialize(stored)

          expect(exported_column.raw).to be(false)
          expect(JSON.parse(type.serialize(exported_column))).not_to have_key('raw')
        end
      end
    end
  end

  describe 'cast from the form' do
    let(:column) { Columns::JSONPathColumn.new(procedure_id: 1, stable_id: 17, tdc_type: 'communes', label: 'Département', jsonpath: '$.department_code', displayable: true, mandatory: false) }

    before { allow(Column).to receive(:find).and_return(column) }

    it 'keeps the raw flag posted by the checkbox' do
      expect(type.cast(ExportedColumn.new(column:, libelle: 'Département', raw: true).id).raw).to be(true)
    end
  end
end
