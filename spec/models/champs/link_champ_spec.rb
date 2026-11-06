# frozen_string_literal: true

describe Champs::LinkChamp do
  let(:procedure) { create(:procedure, private_type_de_champs: [{ type: :link }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_champs_private.first }

  describe 'normalization' do
    it 'adds the https scheme to a bare host and strips spaces' do
      champ.value = " outil-metier.gouv.fr/dossiers/42 "
      expect(champ.value).to eq('https://outil-metier.gouv.fr/dossiers/42')
    end
  end

  describe 'validation' do
    before { champ.value = value }

    context 'when blank' do
      let(:value) { nil }
      it { expect(champ.validate(:champ_value)).to be(true) }
    end

    context 'with an https url' do
      let(:value) { 'https://outil-metier.gouv.fr/dossiers/42?onglet=suivi' }
      it { expect(champ.validate(:champ_value)).to be(true) }
    end

    context 'with a javascript: url' do
      let(:value) { 'javascript:alert(1)' }

      it do
        champ.validate(:champ_value)
        expect(champ.errors).to be_of_kind(:value, :url)
      end
    end

    context 'with a private address' do
      let(:value) { 'http://192.168.0.1/admin' }

      it do
        champ.validate(:champ_value)
        expect(champ.errors).to be_of_kind(:value, :private_ip_url)
      end
    end
  end

  describe 'type de champ' do
    it 'is only offered as a private annotation, behind a feature flag' do
      expect(TypesDeChamp::LinkTypeDeChamp).to be_private_only
      expect(TypesDeChamp::LinkTypeDeChamp.feature_flag).to eq(:link_type_de_champ)
    end
  end
end
