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
  end
end
