# frozen_string_literal: true

RSpec.describe Dossiers::ReferentielComponent, type: :component do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :referentiel, referentiel: }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_public_champs.first }

  let(:pending) { false }
  let(:not_found) { false }
  let(:value_json) { nil }
  let(:external_error) { false }
  let(:value) { 'ABC123' }
  let(:external_id) { value }

  subject { render_inline(described_class.new(champ:, profile: 'usager')) }

  before do
    allow(champ).to receive(:pending?).and_return(pending)
    allow(champ).to receive(:value_json).and_return(value_json)
    allow(champ).to receive(:external_data_not_found?).and_return(not_found)
    allow(champ).to receive(:external_error?).and_return(external_error)
    allow(champ).to receive(:value).and_return(value)
    allow(champ).to receive(:external_id).and_return(external_id)
    allow(champ).to receive(:to_s).and_return(value.to_s)
    allow(Dossiers::ExternalChampComponent).to receive(:new).and_call_original
    subject
  end

  # exact_match : external_id est renseigné mais value reste blank jusqu'au succès du fetch
  context 'when the champ is waiting for a job (exact_match)' do
    let(:external_id) { 'ABC123' }
    let(:value) { nil }
    let(:pending) { true }

    it 'displays a pending message with the identifier' do
      expect(subject).to have_text('Récupération des données en cours pour l’identifiant « ABC123 »')
    end
  end

  context 'when the external data is not found (exact_match)' do
    let(:external_id) { 'ABC123' }
    let(:value) { nil }
    let(:not_found) { true }

    it 'displays a not found message with the identifier' do
      expect(subject).to have_text('Aucune donnée trouvée pour l’identifiant « ABC123 »')
    end
  end

  context 'when the champ is in external error with a technical error (exact_match)' do
    let(:external_id) { 'ABC123' }
    let(:value) { nil }
    let(:external_error) { true }

    it 'displays a generic error message with the identifier' do
      expect(subject).to have_text('Une erreur est survenue lors de la récupération des données pour l’identifiant « ABC123 »')
    end
  end

  context 'when the value_json is present' do
    let(:value) { 'Mon référentiel' }
    let(:value_json) { { something: true } }

    it 'renders ExternalChampComponent with the identifier' do
      expect(Dossiers::ExternalChampComponent).to have_received(:new) do |data:, **|
        expect(data).to include(['Identifiant', 'Mon référentiel'])
      end
    end
  end

  context 'when the value is blank' do
    let(:value) { nil }

    it 'displays a not filled message' do
      expect(subject).to have_text('Non renseigné')
    end
  end
end
