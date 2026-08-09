# frozen_string_literal: true

describe Champs::PaysChamp, type: :model do
  let(:champ) { described_class.new(value: nil) }
  before { allow(champ).to receive(:type_de_champ).and_return(TypesDeChamp::TypeDeChampBase.build(build(:type_de_champ_pays))) }

  describe 'value' do
    it 'with code' do
      champ.value = 'GB'
      expect(champ.external_id).to eq('GB')
      expect(champ.value).to eq('Royaume-Uni')
      expect(champ.selected).to eq('GB')
      expect(champ.to_s).to eq('Royaume-Uni')
      I18n.with_locale(:en) do
        expect(champ.to_s).to eq('United Kingdom')
      end
      I18n.with_locale(:fr) do
        expect(champ.to_s).to eq('Royaume-Uni')
      end
    end

    it 'with name' do
      champ.value = 'Royaume-Uni'
      expect(champ.external_id).to eq('GB')
      expect(champ.value).to eq('Royaume-Uni')
      expect(champ.selected).to eq('GB')
      expect(champ.to_s).to eq('Royaume-Uni')
    end

    it 'with nil' do
      champ.write_attribute(:value, 'Royaume-Uni')
      champ.write_attribute(:external_id, 'GB')
      champ.value = nil
      expect(champ.external_id).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with blank' do
      champ.write_attribute(:value, 'Royaume-Uni')
      champ.write_attribute(:external_id, 'GB')
      champ.value = ''
      expect(champ.external_id).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with initial nil' do
      champ.write_attribute(:value, nil)
      expect(champ.external_id).to be_nil
      expect(champ.value).to be_nil
      expect(champ.selected).to be_nil
      expect(champ.to_s).to eq('')
    end

    it 'with initial name' do
      champ.write_attribute(:value, 'Royaume-Uni')
      expect(champ.external_id).to be_nil
      expect(champ.value).to eq('Royaume-Uni')
      expect(champ.selected).to eq('GB')
      expect(champ.to_s).to eq('Royaume-Uni')
    end

    it 'with initial bad name' do
      champ.write_attribute(:value, 'ROYAUME-UNIS')
      expect(champ.external_id).to be_nil
      expect(champ.value).to eq('ROYAUME-UNIS')
      expect(champ.selected).to eq('ROYAUME-UNIS')
      expect(champ.to_s).to eq('ROYAUME-UNIS')
    end
  end
end
