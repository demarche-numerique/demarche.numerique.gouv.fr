# frozen_string_literal: true

describe 'shared/dossiers/normalized_address', type: :view do
  let(:subject) { render 'shared/dossiers/normalized_address', address: }

  context 'given an champ' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:address) { AddressProxy.new(dossier.project_champs_public.first) }

    it 'render address' do
      expect(subject).to have_text("6 RUE RAOUL NORDLING")
      expect(subject).to have_text("Bois-Colombes")
      expect(subject).to have_text("92270")
      expect(subject).to have_text("92009")
      expect(subject).to have_text("Hauts-de-Seine – 92")
      expect(subject).to have_text("Île-de-France – 11")
    end
  end

  context 'given an etablissement' do
    let(:etablissement) { create(:etablissement) }
    let(:address) { AddressProxy.new(etablissement) }

    it 'render address' do
      expect(subject).to have_text("6 RUE RAOUL NORDLING")
      expect(subject).to have_text("BOIS COLOMBES 92270")
      expect(subject).to have_text("92009")
      expect(subject).to have_text("92270")
      expect(subject).to have_text("Hauts-de-Seine – 92")
      expect(subject).to have_text("Île-de-France – 11")
    end
  end

  context 'given a partial etablissement address' do
    let(:etablissement) { create(:etablissement) }
    before { allow(etablissement).to receive(:code_postal).and_return(nil) }
    let(:address) { AddressProxy.new(etablissement) }

    it 'render address' do
      expect { subject }.not_to raise_error
    end
  end
end
