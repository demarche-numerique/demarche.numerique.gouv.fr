# frozen_string_literal: true

RSpec.describe TypesDeChamp::PrefillAddress do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :address }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:type_de_champ) { procedure.active_revision.type_de_champs.first }

  describe 'ancestors' do
    subject { described_class.new(type_de_champ, procedure.active_revision) }

    it { is_expected.to be_kind_of(TypesDeChamp::Prefill) }
  end

  describe '#to_assignable_attributes' do
    let(:champ) { dossier.champ_data.first }
    subject { described_class.build(type_de_champ, procedure.active_revision).to_assignable_attributes(champ, value) }

    context 'when the value is nil' do
      let(:value) { nil }
      it { is_expected.to match(nil) }
    end

    context 'when the value is empty' do
      let(:value) { nil }
      it { is_expected.to match(nil) }
    end

    context 'when the value is present' do
      let(:value) { 'hello' }
      it { is_expected.to match({ value: 'hello', external_id: 'hello' }) }
    end
  end
end
