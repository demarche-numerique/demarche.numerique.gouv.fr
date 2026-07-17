# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillNumberTypeDeChamp do
  let(:procedure) { build(:procedure) }
  let(:champ) { Champs::IntegerNumberChamp.new }

  describe 'ancestors' do
    subject { described_class.build(build(:type_de_champ_integer_number, procedure: procedure), procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::PrefillTypeDeChamp) }
  end

  describe '.build' do
    it 'is used for integer_number and decimal_number types de champ' do
      [build(:type_de_champ_integer_number), build(:type_de_champ_decimal_number)].each do |type_de_champ|
        expect(TypesDeChamp::PrefillTypeDeChamp.build(type_de_champ, procedure.active_revision)).to be_kind_of(described_class)
      end
    end
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    context 'with an integer number type de champ' do
      let(:type_de_champ) { build(:type_de_champ_integer_number, procedure: procedure) }

      context 'when the value is an integer string' do
        let(:value) { '42' }

        it { is_expected.to eq({ value: '42' }) }
      end

      context 'when the value is a negative integer string' do
        let(:value) { '-42' }

        it { is_expected.to eq({ value: '-42' }) }
      end

      context 'when the value contains spaces' do
        let(:value) { '3 000' }

        it { is_expected.to eq({ value: '3000' }) }
      end

      context 'when the value is an Integer' do
        let(:value) { 42 }

        it { is_expected.to eq({ value: '42' }) }
      end

      context 'when the value is a Float' do
        let(:value) { 42.2 }

        it 'truncates to integer' do
          is_expected.to eq({ value: '42' })
        end
      end

      context 'when the value is not an integer' do
        let(:value) { 'non integer string' }

        it { is_expected.to be_nil }
      end

      context 'when the value is a decimal' do
        let(:value) { '3.14' }

        it { is_expected.to be_nil }
      end

      context 'when the type de champ expects a positive number' do
        before { type_de_champ.positive_number = '1' }

        context 'and the number is positive' do
          let(:value) { '42' }

          it { is_expected.to eq({ value: '42' }) }
        end

        context 'and the number is negative' do
          let(:value) { '-42' }

          it { is_expected.to be_nil }
        end
      end

      context 'when the type de champ expects a number in a range' do
        before do
          type_de_champ.range_number = '1'
          type_de_champ.min_number = '10'
          type_de_champ.max_number = '20'
        end

        context 'and the number is in the range' do
          let(:value) { '15' }

          it { is_expected.to eq({ value: '15' }) }
        end

        context 'and the number is out of the range' do
          let(:value) { '42' }

          it { is_expected.to be_nil }
        end
      end
    end

    context 'with a decimal number type de champ' do
      let(:type_de_champ) { build(:type_de_champ_decimal_number, procedure: procedure) }
      let(:champ) { Champs::DecimalNumberChamp.new }

      context 'when the value is a decimal string' do
        let(:value) { '3.14' }

        it { is_expected.to eq({ value: '3.14' }) }
      end

      context 'when the value uses a comma separator' do
        let(:value) { '3,14' }

        it { is_expected.to eq({ value: '3.14' }) }
      end

      context 'when the value is an integer string' do
        let(:value) { '42' }

        it { is_expected.to eq({ value: '42' }) }
      end

      context 'when the value is a Float' do
        let(:value) { 3.14 }

        it { is_expected.to eq({ value: '3.14' }) }
      end

      context 'when the value is an Integer' do
        let(:value) { 2 }

        it { is_expected.to eq({ value: '2' }) }
      end

      context 'when the value is not a number' do
        let(:value) { 'non decimal string' }

        it { is_expected.to be_nil }
      end

      context 'when the value has more than 3 decimal digits' do
        let(:value) { '3.1415' }

        it { is_expected.to be_nil }
      end

      context 'when the type de champ expects a positive number' do
        before { type_de_champ.positive_number = '1' }

        context 'and the number is positive' do
          let(:value) { '3.14' }

          it { is_expected.to eq({ value: '3.14' }) }
        end

        context 'and the number is negative' do
          let(:value) { '-3.14' }

          it { is_expected.to be_nil }
        end
      end

      context 'when the type de champ expects a number in a range' do
        before do
          type_de_champ.range_number = '1'
          type_de_champ.min_number = '1'
          type_de_champ.max_number = '3'
        end

        context 'and the number is in the range' do
          let(:value) { '2.5' }

          it { is_expected.to eq({ value: '2.5' }) }
        end

        context 'and the number is out of the range' do
          let(:value) { '3.14' }

          it { is_expected.to be_nil }
        end
      end
    end
  end
end
