# frozen_string_literal: true

describe Champs::PreRempliChamp do
  let(:types_de_champ_public) { [{ type: :pre_rempli }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.project_champs_public.first.tap { _1.update_column(:value, value) } }

  describe '#selected' do
    subject { champ.selected }

    context 'when value is present' do
      let(:value) { 'option1' }
      it { is_expected.to eq('option1') }
    end

    context 'when value is nil' do
      let(:value) { nil }
      it { is_expected.to be_nil }
    end
  end

  describe '#blank?' do
    subject { champ.blank? }

    context 'when value is nil' do
      let(:value) { nil }
      it { is_expected.to be_truthy }
    end

    context 'when value is empty string' do
      let(:value) { '' }
      it { is_expected.to be_truthy }
    end

    context 'when value is present' do
      let(:value) { 'something' }
      it { is_expected.to be_falsey }
    end
  end
end
