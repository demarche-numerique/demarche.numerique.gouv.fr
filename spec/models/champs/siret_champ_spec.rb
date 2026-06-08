# frozen_string_literal: true

describe Champs::SiretChamp do
  let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first.tap { _1.update(external_id:, etablissement:) } }
  let(:external_id) { "" }
  let(:etablissement) { nil }

  describe '#validate' do
    subject { champ.tap { _1.validate(:champs_public_value) } }

    context 'when empty' do
      let(:external_id) { nil }

      it { is_expected.to be_valid }
    end

    context 'with invalid format' do
      let(:external_id) { "12345" }

      it { subject.errors[:external_id].should include('doit comporter exactement 14 chiffres. Exemple : 500 001 234 56789') }
    end

    context 'with invalid checksum' do
      let(:external_id) { "12345678901234" }

      it { subject.errors[:external_id].should include("comporte une erreur de saisie. Corrigez-la.") }
    end

    context 'with valid format but no etablissement' do
      let(:external_id) { "12345678901245" }

      it { subject.errors[:external_id].should include("ne correspond pas à un établissement existant") }
    end

    context 'with valid SIRET and etablissement' do
      let(:external_id) { "12345678901245" }
      let(:etablissement) { build(:etablissement, siret: external_id) }

      it { is_expected.to be_valid }
    end

    context 'when external fetch is pending' do
      let(:external_id) { "12345678901245" }

      before { champ.update_columns(external_state: 'waiting_for_job') }

      it 'does not block submission (pending is non-blocking)' do
        expect(subject).to be_valid
      end
    end

    context 'when external fetch failed' do
      let(:external_id) { "12345678901245" }
      let(:exception) { ExternalDataException.new(error: 'Not retryable', code: 404, kind: :not_found) }

      before do
        champ.update_columns(
          external_state: 'external_error',
          fetch_external_data_exceptions: [exception]
        )
      end

      it 'adds the external error on value only' do
        expect(subject.errors[:value]).to include(I18n.t('activerecord.errors.messages.code_404'))
        expect(subject.errors[:external_id]).to be_empty
      end
    end
  end

  describe '.fetch_external_data' do
    let(:api_etablissement_status) { 200 }
    let(:api_etablissement_body) { File.read('spec/fixtures/files/api_entreprise/etablissements.json') }
    let(:token_expired) { false }
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let!(:champ) { dossier.champs.first.tap { _1.update!(etablissement: create(:etablissement), external_id: siret, external_state: 'waiting_for_job') } }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(status: api_etablissement_status, body: api_etablissement_body)
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles)
        .and_return(["attestations_fiscales", "attestations_sociales", "bilans_entreprise_bdf"])
    end

    subject(:fetch_external_data) { champ.fetch_external_data }

    shared_examples 'an error occured' do
      it { expect(fetch_external_data).to be_failure }
    end

    context 'when the API is unavailable due to network error' do
      let(:siret) { '82161143100015' }
      let(:api_etablissement_status) { 503 }

      before { allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:insee_sirene).and_return(true) }

      it_behaves_like 'an error occured'

      it 'returns a retryable failure' do
        expect(fetch_external_data).to be_failure
        expect(fetch_external_data.failure[:retryable]).to be true
      end
    end

    context 'when the API is unavailable due to an api maintenance or pb' do
      let(:siret) { '82161143100015' }
      let(:api_etablissement_status) { 502 }

      before { allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:insee_sirene).and_return(false) }

      it { expect { fetch_external_data }.to change { champ.reload.etablissement } }

      it { expect { fetch_external_data }.to change { champ.reload.etablissement.as_degraded_mode? }.to(true) }

      it { expect { fetch_external_data }.to change { Etablissement.count }.by(1) }

      it 'returns a retryable failure to trigger job retry' do
        expect(fetch_external_data).to be_failure
        expect(fetch_external_data.failure[:retryable]).to be true
      end
    end

    context 'when the SIRET is valid but unknown' do
      let(:siret) { '00000000000000' }
      let(:api_etablissement_status) { 404 }

      it_behaves_like 'an error occured'
    end

    context 'when the SIRET informations are retrieved successfully' do
      let(:siret) { '30613890001294' }
      let(:api_etablissement_status) { 200 }
      let(:api_etablissement_body) { File.read('spec/fixtures/files/api_entreprise/etablissements.json') }

      it { expect { fetch_external_data }.to change { champ.reload.etablissement.siret }.to(siret) }

      it { expect { fetch_external_data }.to change { champ.reload.etablissement.naf }.to("8411Z") }

      it { expect { fetch_external_data }.to change { Etablissement.count }.by(1) }

      it { expect(fetch_external_data).to be_success }

      it "fetches the entreprise raison sociale" do
        fetch_external_data
        expect(champ.reload.etablissement.entreprise_raison_sociale).to eq("DIRECTION INTERMINISTERIELLE DU NUMERIQUE")
      end
    end
  end

  describe '#fetch_external_data (kind classification)' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champs.first }
    before { champ.update_column(:external_id, '12345678901234') }

    context 'when API returns not_found' do
      before do
        allow(APIEntrepriseService).to receive(:create_etablissement_with_fallback)
          .and_return(Dry::Monads::Failure(type: :not_found, code: 404, retryable: false))
      end

      it 'wraps as kind: :not_found' do
        result = champ.fetch_external_data
        expect(result).to be_failure
        expect(result.failure[:kind]).to eq(:not_found)
        expect(result.failure[:code]).to eq(404)
      end
    end

    context 'when API returns a generic technical failure' do
      before do
        allow(APIEntrepriseService).to receive(:create_etablissement_with_fallback)
          .and_return(Dry::Monads::Failure(type: :network, code: 503, retryable: true))
      end

      it 'wraps as kind: :technical_error' do
        expect(champ.fetch_external_data.failure[:kind]).to eq(:technical_error)
      end
    end

    context 'when API returns Success in degraded mode' do
      let(:etablissement) { instance_double(Etablissement, as_degraded_mode?: true) }
      before do
        allow(APIEntrepriseService).to receive(:create_etablissement_with_fallback)
          .and_return(Dry::Monads::Success(etablissement))
      end

      it 'wraps degraded mode as kind: :technical_error' do
        expect(champ.fetch_external_data.failure[:kind]).to eq(:technical_error)
      end
    end
  end

  describe '#reset_external_data!' do
    let(:external_id) { "12345678901245" }
    let(:etablissement) { create(:etablissement, siret: external_id) }

    it 'destroys the old etablissement to avoid orphans' do
      old_etablissement = champ.etablissement
      expect(old_etablissement).to be_persisted

      champ.reset_external_data!

      expect(champ.reload.etablissement).to be_nil
      expect { old_etablissement.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
