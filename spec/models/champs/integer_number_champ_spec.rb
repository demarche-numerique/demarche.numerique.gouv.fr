# frozen_string_literal: true

describe Champs::IntegerNumberChamp do
  let(:types_de_champ_public) { [{ type: :integer_number }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_public_champs.first.tap { _1.update(value:) } }
  let(:value) { nil }
  subject { champ.validate(:champ_value) }

  describe '#valid?' do
    context 'when the value is integer number' do
      let(:value) { 2 }

      it { is_expected.to be_truthy }
    end

    context 'when the value is decimal number' do
      let(:value) { 2.6 }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être un nombre entier (sans chiffres après la virgule)"])
      end
    end

    context 'when the value is not a number' do
      let(:value) { 'toto' }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être un nombre entier (sans chiffres après la virgule)"])
      end
    end

    context 'when the value is a number with sapces' do
      let(:value) { ' 120 ' }

      it 'is valid and is formated' do
        is_expected.to be_truthy
        champ.save!
        expect(champ.value).to eq('120')
      end
    end

    context 'when the value is blank' do
      let(:value) { '' }

      it { is_expected.to be_truthy }
    end

    context 'when the value is nil' do
      let(:value) { nil }

      it { is_expected.to be_truthy }
    end

    context 'when the value is negative' do
      context 'negative values are accepted' do
        let(:value) { -1 }

        it { is_expected.to be_truthy }
      end

      context 'negative values are not accepted' do
        before { champ.type_de_champ.record.update(options: { positive_number: '1' }) }
        let(:value) { -1 }

        it 'is not valid and contains errors' do
          is_expected.to be_falsey
          expect(champ.errors[:value]).to eq(["doit être un nombre positif"])
        end
      end
    end

    context 'when there is a range' do
      before { champ.type_de_champ.record.update(options: { range_number: '1', min_number: '2', max_number: '18' }) }
      context 'the value is in the range' do
        let(:value) { 4 }

        it { is_expected.to be_truthy }
      end

      context 'the value is not in the range' do
        let(:value) { 19 }

        it 'is not valid and contains errors' do
          is_expected.to be_falsey
          expect(champ.errors[:value]).to eq(["doit être un nombre compris entre 2 et 18"])
        end
      end

      context 'the value is bigger than max' do
        before { champ.type_de_champ.record.update(options: { range_number: '1', min_number: '', max_number: '18' }) }
        let(:value) { 19 }

        it 'is not valid and contains errors' do
          is_expected.to be_falsey
          expect(champ.errors[:value]).to eq(["doit être un nombre inférieur ou égal à 18"])
        end
      end

      context 'the value is smaller than min' do
        before { champ.type_de_champ.record.update(options: { range_number: '1', min_number: '2', max_number: '' }) }
        let(:value) { 1 }

        it 'is not valid and contains errors' do
          is_expected.to be_falsey
          expect(champ.errors[:value]).to eq(["doit être un nombre supérieur ou égal à 2"])
        end
      end

      context 'the range is not activated' do
        before { champ.type_de_champ.record.update(options: { range_number: '0', min_number: '2', max_number: '18' }) }
        let(:value) { 19 }

        it { is_expected.to be_truthy }
      end

      context 'the range is activated but min and max values are not defined' do
        before { champ.type_de_champ.record.update(options: { range_number: '0', min_number: '', max_number: '' }) }
        let(:value) { 19 }

        it { is_expected.to be_truthy }
      end
    end
  end
end
