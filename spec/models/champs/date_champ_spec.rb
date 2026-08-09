# frozen_string_literal: true

describe Champs::DateChamp do
  let(:types_de_champ_public) { [{ type: :date }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:date_champ) { dossier.champ_data.first }

  # The conversion matrix itself is covered by spec/lib/date_detection_utils_spec.rb;
  # here we only check that assignment is wired to it.
  describe 'value normalization' do
    it 'converts a non-ISO date to ISO on assignment' do
      expect(champ_with_value("31/12/2017").value).to eq("2017-12-31")
    end

    it 'converts to nil if not a valid date' do
      expect(champ_with_value("13/13/2023").value).to be_nil
    end

    it 'preserves nil' do
      expect(champ_with_value(nil).value).to be_nil
    end
  end

  describe 'iso_8601 validation' do
    it 'reports an error whose message can be generated (RAILS-MAQ)' do
      allow(date_champ).to receive(:value).and_return("2023-30-01")

      expect(date_champ.validate(:champ_value)).to be(false)
      expect(date_champ.errors.first.attribute).to eq(:value)
      expect { date_champ.errors.map(&:message) }.not_to raise_error
      expect(date_champ.errors.first.message).to eq('doit être une date correctement formatée')
    end
  end

  # Rows written before the current parsing rules are never re-normalized on
  # load; saving must drop them instead of failing the iso_8601 validation
  # before the caller assigns anything (RAILS-MC5).
  describe 'legacy value self-heal' do
    before do
      # Raw SQL fragment: a hash through update_all would run the normalizer.
      dossier.champ_data.where(id: date_champ.id).update_all(["value = ?", "2021-06-31T00:00:00"])
      date_champ.reload
    end

    it 'drops an unparsable stored value on save instead of failing validation' do
      expect(Sentry).to receive(:capture_message)
      expect(date_champ.save).to be(true)
      expect(date_champ.reload.value).to be_nil
    end

    it 'lets a freshly assigned value win over the heal' do
      date_champ.value = "31/12/2017"
      expect(date_champ.save).to be(true)
      expect(date_champ.reload.value).to eq("2017-12-31")
    end

    it 'leaves a parsable stored value alone' do
      date_champ.update!(value: "2020-06-20")
      expect(Sentry).not_to receive(:capture_message)
      expect(date_champ.save).to be(true)
      expect(date_champ.reload.value).to eq("2020-06-20")
    end
  end

  describe "#to_s" do
    it "format the date" do
      champ_with_value("2020-06-20")
      expect(date_champ.to_s).to eq("20 juin 2020")
    end

    it "does not fail when a legacy value stored in database is not iso" do
      allow(date_champ).to receive(:value).and_return("2023-30-01")
      expect(date_champ.to_s).to eq("2023-30-01")
    end
  end

  context 'when the value is not in the past' do
    let(:champ) { dossier.root_champs_public.first.tap { _1.update(value:) } }
    subject { champ.validate(:champ_value) }

    context 'all dates are accepted' do
      let(:value) { Date.today }

      it { is_expected.to be_truthy }
    end

    context 'dates not in past are not accepted' do
      before { champ.type_de_champ.record.update(options: { date_in_past: '1' }) }
      let(:value) { Date.today }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être une date dans le passé"])
      end
    end
  end

  context 'when there is a range' do
    let(:champ) { dossier.root_champs_public.first.tap { _1.update(value:) } }
    subject { champ.validate(:champ_value) }

    before { champ.type_de_champ.record.update(options: { range_date: '1', start_date: '2017-11-30', end_date: '2017-12-31' }) }
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
      before { champ.type_de_champ.record.update(options: { range_date: '1', start_date: '', end_date: '2017-12-31' }) }
      let(:value) { "2018-12-15" }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être une date inférieure ou égale au 31 décembre 2017"])
      end
    end

    context 'the value is smaller than min' do
      before { champ.type_de_champ.record.update(options: { range_date: '1', start_date: '2017-11-30', end_date: '' }) }
      let(:value) { "2016-12-15" }

      it 'is not valid and contains errors' do
        is_expected.to be_falsey
        expect(champ.errors[:value]).to eq(["doit être une date supérieure ou égale au 30 novembre 2017"])
      end
    end

    context 'the range is not activated' do
      before { champ.type_de_champ.record.update(options: { range_date: '0', start_date: '2017-11-30', end_date: '2017-12-31' }) }
      let(:value) { "2017-12-15" }

      it { is_expected.to be_truthy }
    end

    context 'the range is activated but min and max values are not defined' do
      before { champ.type_de_champ.record.update(options: { range_date: '0', start_date: '', end_date: '' }) }
      let(:value) { "2017-12-15" }

      it { is_expected.to be_truthy }
    end
  end

  context 'when birthdate option is enabled' do
    let(:champ) { dossier.root_champs_public.first.tap { _1.update(value:) } }
    subject { champ.validate(:champ_value) }

    before { champ.type_de_champ.record.update(options: { birthdate: "1" }) }

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
      before { champ.type_de_champ.record.update(options: { birthdate: "1", date_in_past: '1', range_date: '1', start_date: '2020-01-01', end_date: '2020-12-31' }) }
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
