# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillDateTypeDeChamp do
  let(:procedure) { build(:procedure) }

  describe 'ancestors' do
    subject { described_class.build(build(:type_de_champ_date, procedure: procedure), procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::PrefillTypeDeChamp) }
  end

  describe '.build' do
    it 'is used for date and datetime types de champ' do
      [build(:type_de_champ_date), build(:type_de_champ_datetime)].each do |type_de_champ|
        expect(TypesDeChamp::PrefillTypeDeChamp.build(type_de_champ, procedure.active_revision)).to be_kind_of(described_class)
      end
    end
  end

  describe '#to_assignable_attributes' do
    subject(:to_assignable_attributes) { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    context 'with a date type de champ' do
      let(:type_de_champ) { build(:type_de_champ_date, procedure: procedure) }
      let(:champ) { Champs::DateChamp.new }

      context 'when the value is an ISO8601 date' do
        let(:value) { '2022-12-22' }

        it { is_expected.to eq({ value: '2022-12-22' }) }
      end

      context 'when the value is a French formatted date' do
        let(:value) { '31/12/2017' }

        it { is_expected.to eq({ value: '2017-12-31' }) }
      end

      context 'when the value is not a date' do
        let(:value) { 'value' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a String' do
        let(:value) { { "injected" => "x" } }

        it { is_expected.to be_nil }
      end

      context 'when the value is a unix timestamp (Integer)' do
        let(:date) { Date.new(2025, 7, 10) }
        let(:value) { date.to_time.to_i }

        it { is_expected.to eq({ value: '2025-07-10' }) }
      end

      context 'when the value is a unix timestamp (String)' do
        let(:date) { Date.new(2025, 7, 10) }
        let(:value) { date.to_time.to_i.to_s }

        it { is_expected.to eq({ value: '2025-07-10' }) }
      end

      context 'when the type de champ expects a date in the past' do
        before { type_de_champ.date_in_past = '1' }

        context 'and the date is in the past' do
          let(:value) { '2000-01-01' }

          it { is_expected.to eq({ value: '2000-01-01' }) }
        end

        context 'and the date is not in the past' do
          let(:value) { (Date.today + 1.day).iso8601 }

          it { is_expected.to be_nil }
        end
      end

      context 'when the type de champ expects a date in a range' do
        before do
          type_de_champ.range_date = '1'
          type_de_champ.start_date = '2022-01-01'
          type_de_champ.end_date = '2022-12-31'
        end

        context 'and the date is in the range' do
          let(:value) { '2022-06-15' }

          it { is_expected.to eq({ value: '2022-06-15' }) }
        end

        context 'and the date is out of the range' do
          let(:value) { '2023-06-15' }

          it { is_expected.to be_nil }
        end
      end
    end

    context 'with a datetime type de champ' do
      let(:type_de_champ) { build(:type_de_champ_datetime, procedure: procedure) }
      let(:champ) { Champs::DatetimeChamp.new }

      context 'when the value is an ISO8601 datetime' do
        let(:value) { '2022-12-22T10:30' }

        it { is_expected.to eq({ value: Time.zone.parse('2022-12-22T10:30').iso8601 }) }
      end

      context 'when the value is not a datetime' do
        let(:value) { 'value' }

        it { is_expected.to be_nil }
      end

      context 'when the value is a wrongly formatted datetime' do
        let(:value) { '12-22-2022T10:30' }

        it { is_expected.to be_nil }
      end

      context 'when the value is not a String' do
        let(:value) { { "injected" => "x" } }

        it { is_expected.to be_nil }
      end

      context 'when the value is a unix timestamp (Float)' do
        let(:datetime) { Time.zone.parse('2025-07-10T14:30:00') }
        let(:value) { datetime.to_f }

        it { is_expected.to eq({ value: datetime.iso8601 }) }
      end

      context 'when the value is a unix timestamp (Integer)' do
        let(:datetime) { Time.zone.parse('2025-07-10T14:30:00') }
        let(:value) { datetime.to_i }

        it { is_expected.to eq({ value: datetime.iso8601 }) }
      end

      context 'when the value is a unix timestamp (String)' do
        let(:datetime) { Time.zone.parse('2025-07-10T14:30:00') }
        let(:value) { datetime.to_f.to_s }

        it { is_expected.to eq({ value: datetime.iso8601 }) }
      end

      context 'when the type de champ expects a date in the past' do
        before { type_de_champ.date_in_past = '1' }

        context 'and the datetime is in the past' do
          let(:value) { '2000-01-01T10:30' }

          it { is_expected.to eq({ value: Time.zone.parse('2000-01-01T10:30').iso8601 }) }
        end

        context 'and the datetime is not in the past' do
          let(:value) { 1.day.from_now.iso8601 }

          it { is_expected.to be_nil }
        end
      end
    end
  end
end
