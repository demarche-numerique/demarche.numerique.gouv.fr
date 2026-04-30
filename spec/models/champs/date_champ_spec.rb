# frozen_string_literal: true

describe Champs::DateChamp do
  let(:types_de_champ_public) { [{ type: :date }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:date_champ) { dossier.champs.first }

  describe '#convert_to_iso8601_date' do
    it 'preserves nil' do
      champ = champ_with_value(nil)
      champ.validate
      expect(champ.value).to be_nil
    end

    it 'converts to nil if empty string' do
      champ = champ_with_value("")
      champ.validate
      expect(champ.value).to be_nil
    end

    it 'converts to nil if not ISO8601' do
      champ = champ_with_value("12-21-2023")
      champ.validate
      expect(champ.value).to be_nil
    end

    it 'converts to nil if not date' do
      champ = champ_with_value("value")
      champ.validate
      expect(champ.value).to be_nil
    end

    it "converts %d/%m/%Y format to ISO" do
      champ = champ_with_value("31/12/2017")
      champ.validate
      expect(champ.value).to eq("2017-12-31")
    end

    it 'preserves if ISO8601' do
      champ = champ_with_value("2023-12-21")
      champ.validate
      expect(champ.value).to eq("2023-12-21")
    end

    it 'converts to nil if false iso' do
      champ = champ_with_value("2023-27-02")
      champ.validate
      expect(champ.value).to eq(nil)
    end
  end

  describe "#to_s" do
    it "format the date" do
      champ_with_value("2020-06-20")
      expect(date_champ.to_s).to eq("20 juin 2020")
    end

    it "does not fail when value is not iso" do
      champ_with_value("2023-30-01")
      expect(date_champ.to_s).to eq("2023-30-01")
    end
  end

  context 'when the value is not in the past' do
    let(:champ) { dossier.champs.first.tap { _1.update(value:) } }
    subject { champ.validate(:champs_public_value) }

    context 'all dates are accepted' do
      let(:value) { Date.today }

      it { is_expected.to be_truthy }
    end

    context 'dates not in past are not accepted' do
      before { champ.type_de_champ.update(options: { date_in_past: '1' }) }
      let(:value) { Date.today }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être une date dans le passé"])
      end
    end
  end

  context 'when there is a range' do
    let(:champ) { dossier.champs.first.tap { _1.update(value:) } }
    subject { champ.validate(:champs_public_value) }

    before { champ.type_de_champ.update(options: { range_date: '1', start_date: '2017-11-30', end_date: '2017-12-31' }) }
    context 'the value is in the range' do
      let(:value) { "2017-12-15" }

      it { is_expected.to be_truthy }
    end

    context 'the value is not in the range' do
      let(:value) { "2017-10-15" }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être une date comprise entre le 30 novembre 2017 et le 31 décembre 2017"])
      end
    end

    context 'the value is bigger than max' do
      before { champ.type_de_champ.update(options: { range_date: '1', start_date: '', end_date: '2017-12-31' }) }
      let(:value) { "2018-12-15" }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être une date inférieure ou égale au 31 décembre 2017"])
      end
    end

    context 'the value is smaller than min' do
      before { champ.type_de_champ.update(options: { range_date: '1', start_date: '2017-11-30', end_date: '' }) }
      let(:value) { "2016-12-15" }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être une date supérieure ou égale au 30 novembre 2017"])
      end
    end

    context 'the range is not activated' do
      before { champ.type_de_champ.update(options: { range_date: '0', start_date: '2017-11-30', end_date: '2017-12-31' }) }
      let(:value) { "2017-12-15" }

      it { is_expected.to be_truthy }
    end

    context 'the range is activated but min and max values are not defined' do
      before { champ.type_de_champ.update(options: { range_date: '0', start_date: '', end_date: '' }) }
      let(:value) { "2017-12-15" }

      it { is_expected.to be_truthy }
    end
  end

  context 'when birthdate option is enabled' do
    let(:champ) { dossier.champs.first.tap { _1.update(value:) } }
    subject { champ.validate(:champs_public_value) }

    before { champ.type_de_champ.update(options: { birthdate: "1" }) }

    context 'valid birthdate' do
      let(:value) { "1990-05-15" }

      it { is_expected.to be_truthy }
    end

    context 'born today is valid' do
      let(:value) { Date.today.iso8601 }

      it { is_expected.to be_truthy }
    end

    context 'date before 1900 is not valid' do
      let(:value) { "1899-12-31" }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors.where(:value, :invalid_birthdate)).to be_present
      end
    end

    context 'date in the future is not valid' do
      let(:value) { (Date.today + 1).iso8601 }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors.where(:value, :invalid_birthdate)).to be_present
      end
    end

    context 'birthdate takes precedence over date_in_past and range_date' do
      before { champ.type_de_champ.update(options: { birthdate: "1", date_in_past: '1', range_date: '1', start_date: '2020-01-01', end_date: '2020-12-31' }) }
      let(:value) { "1990-05-15" }

      it 'validates as birthdate, ignoring other constraints' do
        is_expected.to be_truthy
      end
    end
  end

  def champ_with_value(number)
    date_champ.tap { |c| c.value = number }
  end
end
