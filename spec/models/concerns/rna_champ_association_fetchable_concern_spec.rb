# frozen_string_literal: true

RSpec.describe RNAChampAssociationFetchableConcern do
  describe '#fetch_association!' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :rna }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.find(&:rna?) }
    let(:rna) { 'W595001988' }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/djepva\/api-association\/associations\/open_data\/#{rna}/)
        .to_return(body:, status:)
    end

    subject(:fetch_association!) { champ.fetch_association!(rna) }

    context 'when the association is found' do
      let(:status) { 200 }
      let(:body) { File.read('spec/fixtures/files/api_entreprise/associations.json') }

      it 'is a pure side-effect (returns nil)' do
        expect(fetch_association!).to be_nil
      end

      it 'stores the data and clears any previous exception' do
        fetch_association!
        expect(champ.reload.data).to be_present
        expect(champ.fetch_external_data_exceptions).to be_empty
      end
    end

    context 'when the RNA is unknown (API returns 404)' do
      let(:status) { 404 }
      let(:body) { '' }

      it 'records a :not_found exception and stores no data' do
        fetch_association!
        expect(champ.reload.data).to be_nil
        expect(champ.fetch_external_data_exceptions.first.kind).to eq(:not_found)
      end
    end

    context 'when the provider is down (retryable error + djepva_association down)' do
      let(:status) { 503 }
      let(:body) { File.read('spec/fixtures/files/api_entreprise/associations.json') }

      before do
        allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:djepva_association).and_return(false)
      end

      it 'records a :technical_error, adds no validation error and does not report' do
        expect(APIEntrepriseService).not_to receive(:report_error)
        fetch_association!
        expect(champ.errors[:value]).to be_empty
        expect(champ.reload.data).to be_nil
        expect(champ.fetch_external_data_exceptions.first.kind).to eq(:technical_error)
      end
    end

    context 'when the API errors while the provider is up' do
      let(:status) { 502 }
      let(:body) { '' }

      before do
        allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:djepva_association).and_return(true)
      end

      it 'records a :technical_error and reports the error' do
        expect(APIEntrepriseService).to receive(:report_error)
        fetch_association!
        expect(champ.fetch_external_data_exceptions.first.kind).to eq(:technical_error)
      end
    end
  end
end
