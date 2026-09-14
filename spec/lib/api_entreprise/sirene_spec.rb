# frozen_string_literal: true

RSpec.describe APIEntreprise::Sirene do
  let(:procedure) { create(:procedure) }
  let(:siret) { '30613890001294' }

  subject { described_class.fetch_etablissement(siret, procedure.id) }

  def stub_api(status:, body: '')
    stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
      .to_return(body:, status:)
  end

  context 'when the API answers' do
    before { stub_api(status: 200, body: File.read('spec/fixtures/files/api_entreprise/etablissements.json')) }

    it 'builds an etablissement without saving it' do
      expect(subject).to be_success

      etablissement = subject.value!
      expect(etablissement).to be_a(Etablissement)
      expect(etablissement).not_to be_persisted
      expect(etablissement.siret).to eq(siret)
      expect(etablissement.adresse).to be_present
      expect(etablissement.entreprise_raison_sociale).to eq('DIRECTION INTERMINISTERIELLE DU NUMERIQUE')
      expect(etablissement.entreprise_siren).to eq('130025265')
    end
  end

  context 'when the SIRET is unknown' do
    before { stub_api(status: 404) }

    it 'is a plain non retryable failure, not an empty success' do
      expect(subject).to be_failure
      expect(subject.failure[:code]).to eq(404)
      expect(subject.failure[:retryable]).to be false
    end
  end

  context 'when the API is unavailable' do
    before { stub_api(status: 503) }

    it { expect(subject.failure[:retryable]).to be true }
  end

  context 'when the API answers 200 with a body we cannot read' do
    before do
      allow(Sentry).to receive(:capture_exception)
      stub_api(status: 200, body: '{"meta":{}}')
    end

    it 'fails instead of letting the exception escape and freeze the champ' do
      expect(subject).to be_failure
      expect(subject.failure[:code]).to eq(200)
      expect(Sentry).to have_received(:capture_exception)
    end

    it 'is not definitive, so the champ degrades rather than erroring out' do
      expect(subject.failure[:code]).not_to be_in(ExternalDataException::DEFINITIVE_CODES)
    end
  end

  context 'when a single field is unavailable' do
    let(:body) do
      payload = JSON.parse(File.read('spec/fixtures/files/api_entreprise/etablissements.json'))
      payload['data']['enseigne'] = 'Donnée indisponible'
      payload.to_json
    end

    before { stub_api(status: 200, body:) }

    it 'keeps the rest of the payload instead of voiding the etablissement' do
      expect(subject).to be_success
      expect(subject.value!.entreprise_raison_sociale).to eq('DIRECTION INTERMINISTERIELLE DU NUMERIQUE')
    end

    it 'leaves the unavailable field empty rather than storing the sentence' do
      expect(subject.value!.enseigne).to be_nil
    end
  end
end
