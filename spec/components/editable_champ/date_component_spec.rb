# frozen_string_literal: true

describe EditableChamp::DateComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :date, stable_id: 99 }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.project_champs.first }

  let(:component) {
    described_class.new(form: instance_double(ActionView::Helpers::FormBuilder, object_name: "dossier[champs_public_attributes]"), champ:)
  }

  describe '#min_date' do
    subject { component.min_date }

    context 'when birthdate option is enabled' do
      before { champ.type_de_champ.update(birthdate: "1") }

      it { is_expected.to eq(DateLimitValidator::BIRTHDATE_MIN) }
    end

    context 'when range_date with start_date' do
      before { champ.type_de_champ.update(range_date: "1", start_date: "2020-01-01") }

      it { is_expected.to eq("2020-01-01") }
    end

    context 'when no date options' do
      it { is_expected.to be_nil }
    end
  end

  describe '#max_date' do
    subject { component.max_date }

    context 'when birthdate option is enabled' do
      before { champ.type_de_champ.update(birthdate: "1") }

      it { is_expected.to eq(Date.today) }
    end

    context 'when date_in_past' do
      before { champ.type_de_champ.update(date_in_past: "1") }

      it { is_expected.to eq(Date.yesterday) }
    end

    context 'when no date options' do
      it { is_expected.to be_nil }
    end
  end
end
