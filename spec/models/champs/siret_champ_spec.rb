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

      it 'adds a pending error on value' do
        expect(subject.errors[:value]).to include(I18n.t('activerecord.errors.messages.api_response_pending'))
      end
    end

    context 'when external fetch failed' do
      let(:external_id) { "12345678901245" }
      let(:exception) { ExternalDataException.new(error: 'Not retryable', code: 404) }

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
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(status: api_etablissement_status, body: api_etablissement_body)
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v3\/insee\/sirene\/unites_legales\/#{siret[0..8]}/)
        .to_return(body: File.read('spec/fixtures/files/api_entreprise/entreprises.json'), status: 200)
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

      before { expect(APIEntrepriseService).to receive(:api_insee_up?).and_return(true) }

      it_behaves_like 'an error occured'

      it 'sends the error to Sentry' do
        expect(Sentry).to receive(:capture_exception)
        fetch_external_data
      end
    end

    context 'when the API is unavailable due to an api maintenance or pb' do
      let(:siret) { '82161143100015' }
      let(:api_etablissement_status) { 502 }

      before { expect(APIEntrepriseService).to receive(:api_insee_up?).and_return(false) }

      it { expect { fetch_external_data }.to change { champ.reload.etablissement } }

      it { expect { fetch_external_data }.to change { champ.reload.etablissement.as_degraded_mode? }.to(true) }

      it { expect { fetch_external_data }.to change { Etablissement.count }.by(1) }

      it { expect(fetch_external_data).to be_failure }
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
