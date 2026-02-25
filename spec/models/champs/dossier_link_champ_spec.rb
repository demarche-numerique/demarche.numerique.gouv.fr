# frozen_string_literal: true

describe Champs::DossierLinkChamp, type: :model do
  let(:types_de_champ_public) { [{ type: :dossier_link, mandatory: }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first.tap { _1.update(value:) } }
  let(:value) { nil }
  let(:mandatory) { false }

  describe 'prefilling validations' do
    let(:linked_dossier) { create(:dossier) }
    describe 'value' do
      subject { champ.valid?(:prefill) }

      context 'when nil' do
        let(:value) { nil }

        it { expect(subject).to eq(true) }
      end

      context 'when empty' do
        let(:value) { '' }

        it { expect(subject).to eq(true) }
      end

      context 'when an integer' do
        let(:value) { linked_dossier.id }

        it { expect(subject).to eq(true) }
      end

      context 'when a string representing an integer' do
        let(:value) { linked_dossier.id.to_s }

        it { expect(subject).to eq(true) }
      end

      context 'when it can be casted as integer' do
        let(:value) { 'totoro' }

        it { expect(subject).to eq(false) }
      end
    end
  end

  describe 'validation' do
    subject { champ.validate(:champs_public_value) }

    context 'when not mandatory' do
      let(:mandatory) { false }
      let(:value) { nil }
      it { is_expected.to be_truthy }
    end

    context 'when mandatory' do
      let(:mandatory) { true }
      context 'when valid id' do
        let(:value) { create(:dossier).id }
        it { is_expected.to be_truthy }
      end

      context 'when deleted dossier id' do
        let(:deleted_dossier) { create(:deleted_dossier) }
        let(:value) { deleted_dossier.dossier_id.to_s }
        it { is_expected.to be_truthy }
      end

      context 'when invalid id' do
        let(:value) { 'kthxbye' }
        it { is_expected.to be_falsey }
      end

      context 'when unknown id' do
        let(:value) { '999999999' }
        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#deleted_dossier' do
    context 'when value is blank' do
      let(:mandatory) { false }
      let(:value) { nil }
      it { expect(champ.deleted_dossier).to be_nil }
    end

    context 'when value points to an existing dossier' do
      let(:mandatory) { false }
      let(:value) { create(:dossier).id.to_s }
      it { expect(champ.deleted_dossier).to be_nil }
    end

    context 'when value points to a deleted dossier' do
      let(:mandatory) { false }
      let(:deleted) { create(:deleted_dossier) }
      let(:value) { deleted.dossier_id.to_s }
      it { expect(champ.deleted_dossier).to eq(deleted) }
    end
  end
end
