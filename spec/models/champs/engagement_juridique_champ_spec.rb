# frozen_string_literal: true

describe Champs::EngagementJuridiqueChamp do
  describe 'validation' do
    let(:types_de_champ_public) { [{ type: :engagement_juridique }] }
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.root_public_champs.first.tap { _1.update(value:) } }
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

    context 'with *' do
      let(:value) { "*" }
      it do
        is_expected.to be_falsey
        expect(champ.errors.full_messages_for(:value).first.starts_with?("Le numéro d'EJ")).to be_truthy
      end
    end
  end
end
