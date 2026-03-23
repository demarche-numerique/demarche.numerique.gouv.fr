# frozen_string_literal: true

RSpec.describe Dossiers::CommuneComponent, type: :component do
  let(:types_de_champ_public) { [{ type: :communes }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first }

  before do
    allow(Dossiers::ExternalChampComponent).to receive(:new).and_call_original
  end

  context 'when commune is from API Geo' do
    before do
      champ.code_postal = '63290'
      champ.external_id = '63102'
      champ.save!
      render_inline(described_class.new(champ: champ.reload))
    end

    it 'renders ExternalChampComponent with API Geo data and source' do
      expect(Dossiers::ExternalChampComponent).to have_received(:new) do |data:, source:|
        expect(data[0][0]).to eq('Commune')
        expect(data[1][0]).to eq('Code INSEE')
        expect(data[1][1]).to eq('63102')
        expect(data[2][0]).to eq('Département')
        expect(source).to eq('référentiels géographiques nationaux')
      end
    end
  end

  context 'when commune is not in API Geo (free text fallback)' do
    before do
      champ.not_in_api_geo = 'true'
      champ.value = 'Ma commune inconnue'
      champ.save!
      render_inline(described_class.new(champ: champ.reload))
    end

    it 'renders ExternalChampComponent with free text data and source' do
      expect(Dossiers::ExternalChampComponent).to have_received(:new) do |data:, source:|
        expect(data).to eq([
          ['Commune', 'Ma commune inconnue'],
        ])
        expect(source).to eq("saisie libre par l\u2019usager")
      end
    end
  end
end
