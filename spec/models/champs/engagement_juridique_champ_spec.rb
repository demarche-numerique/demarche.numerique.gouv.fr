# frozen_string_literal: true

describe Champs::EngagementJuridiqueChamp do
  describe 'validation' do
    let(:public_type_de_champs) { [{ type: :engagement_juridique }] }
    let(:procedure) { create(:procedure, public_type_de_champs:) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.public_root_champs.first.tap { _1.update(value:) } }
    let(:value) { nil }

    subject { champ.validate(:champ_value) }

    context 'with [A-Z]' do
      let(:value) { "ABC" }
      it { is_expected.to be_truthy }
    end

    context 'with [0-9]' do
      let(:value) { "ABC" }
      it { is_expected.to be_truthy }
    end

    context 'with -' do
      let(:value) { "-" }
      it { is_expected.to be_truthy }
    end

    context 'with _' do
      let(:value) { "_" }
      it { is_expected.to be_truthy }
    end

    context 'with +' do
      let(:value) { "+" }
      it { is_expected.to be_truthy }
    end

    context 'with /' do
      let(:value) { "/" }
      it { is_expected.to be_truthy }
    end

    context 'with a mix of allowed characters' do
      let(:value) { "AB-12_3+4/5" }
      it { is_expected.to be_truthy }
    end

    context 'with *' do
      let(:value) { "*" }
      it do
        is_expected.to be_falsey
        expect(champ.errors.full_messages_for(:value).first.starts_with?("Le numéro d'EJ")).to be_truthy
      end
    end

    context 'with a forbidden character among allowed ones' do
      let(:value) { "Facture n°12" }
      it { is_expected.to be_falsey }
    end
  end
end
