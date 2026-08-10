# frozen_string_literal: true

describe EditableChamp::DatetimeComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :datetime, stable_id: 99, mandatory: true }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  let(:component) {
    described_class.new(form: instance_double(ActionView::Helpers::FormBuilder, object_name: "dossier[champs_public_attributes]"), champ:)
  }

  describe '#formatted_value_for_datetime_locale' do
    subject { component.formatted_value_for_datetime_locale }

    context 'when the value is nil' do
      it 'returns nil and does not make the missing value error disappears' do
        # trigger the missing value error
        dossier.public_champs_valid?

        expect(champ.errors.map { [it.type, it.attribute] }.include?([:missing, :value])).to be_truthy

        is_expected.to be_nil

        expect(champ.errors.map { [it.type, it.attribute] }.include?([:missing, :value])).to be_truthy
      end
    end

    context 'when the value is not a valid datetime' do
      let(:champ) { Champs::DatetimeChamp.new(value: 'invalid', dossier:, stable_id: 99) }

      it { is_expected.to be_nil }
    end

    context 'when the value is a valid datetime' do
      let(:champ) { Champs::DatetimeChamp.new(value: '2020-01-01T00:00:00+01:00', dossier:, stable_id: 99) }

      it { is_expected.to eq('2020-01-01T00:00') }
    end
  end
end
