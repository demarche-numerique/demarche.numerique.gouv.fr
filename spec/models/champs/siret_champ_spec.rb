# frozen_string_literal: true

describe Champs::SiretChamp do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_champs_public.first.tap { _1.update(external_id:, etablissement:) } }
  let(:external_id) { "" }
  let(:etablissement) { nil }

  describe '#validate' do
    subject { champ.tap { _1.validate(:champ_value) } }

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

      it 'adds a pending error on external_id' do
        expect(subject.errors[:external_id]).to include(I18n.t('activerecord.errors.messages.api_response_pending'))
      end
    end

    context 'when the API did not answer' do
      let(:external_id) { "12345678901245" }

      before { champ.update_columns(external_state: 'degraded') }

      it 'does not block the user on a SIRET we could not check' do
        expect(subject.errors[:external_id]).to be_empty
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

      it 'adds the external error on external_id only' do
        expect(subject.errors[:external_id]).to include(I18n.t('activerecord.errors.messages.code_404'))
        expect(subject.errors[:value]).to be_empty
      end
    end
  end

  describe '#fetch_external_data' do
    let(:api_etablissement_status) { 200 }
    let(:api_etablissement_body) { File.read('spec/fixtures/files/api_entreprise/etablissements.json') }
    let(:siret) { '30613890001294' }
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let!(:champ) { dossier.champ_data.first.tap { _1.update!(external_id: siret, external_state: 'waiting_for_job') } }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(status: api_etablissement_status, body: api_etablissement_body)
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles)
        .and_return(["attestations_fiscales", "attestations_sociales", "bilans_entreprise_bdf"])
    end

    subject(:fetch_external_data) { champ.fetch_external_data }

    it 'writes nothing: the champ persists the result' do
      expect { fetch_external_data }.not_to change { Etablissement.count }
    end

    context 'when the API answers' do
      it 'carries the etablissement and the siret' do
        expect(fetch_external_data).to be_success
        expect(fetch_external_data.value![:etablissement].siret).to eq(siret)
        expect(fetch_external_data.value![:value]).to eq(siret)
      end
    end

    context 'when the API does not answer' do
      let(:api_etablissement_status) { 503 }

      it 'is a degraded failure carrying the siret' do
        expect(fetch_external_data).to be_failure
        expect(fetch_external_data.failure[:degraded]).to be true
        expect(fetch_external_data.failure[:value]).to eq(siret)
      end
    end

    context 'when the SIRET is valid but unknown' do
      let(:api_etablissement_status) { 404 }

      it 'is a non retryable failure' do
        expect(fetch_external_data.failure[:retryable]).to be false
        expect(fetch_external_data.failure[:code]).to eq(404)
      end
    end

    context 'when our own token is rejected' do
      let(:api_etablissement_status) { 401 }

      it 'degrades: the SIRET is not at fault and a renewed token will fix it' do
        expect(fetch_external_data.failure[:degraded]).to be true
        expect(fetch_external_data.failure[:code]).to eq(401)
      end
    end
  end

  describe 'the champ once the fetch is handled' do
    let(:api_etablissement_status) { 200 }
    let(:api_etablissement_body) { File.read('spec/fixtures/files/api_entreprise/etablissements.json') }
    let(:siret) { '30613890001294' }
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let!(:champ) { dossier.champ_data.first.tap { _1.update!(external_id: siret, external_state: 'waiting_for_job') } }

    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(status: api_etablissement_status, body: api_etablissement_body)
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles)
        .and_return(["attestations_fiscales", "attestations_sociales", "bilans_entreprise_bdf"])
    end

    subject { champ.fetch!; champ.reload }

    context 'when the API answers' do
      it 'is fetched, with a persisted etablissement' do
        expect(subject).to be_fetched
        expect(subject.etablissement.siret).to eq(siret)
        expect(subject.value).to eq(siret)
      end

      it 'asks for the complementary data' do
        expect { champ.fetch! }.to have_enqueued_job(APIEntreprise::ExtraitKbisJob)
      end
    end

    context 'when the API does not answer' do
      let(:api_etablissement_status) { 503 }

      it 'is degraded, with no etablissement at all' do
        expect(subject).to be_degraded
        expect(subject.etablissement).to be_nil
        expect(subject.value).to eq(siret)
      end

      it 'lets the user submit their dossier' do
        subject.validate(:champ_value)

        expect(subject.errors[:external_id]).to be_empty
      end

      it 'does not ask for the complementary data' do
        expect { champ.fetch! }.not_to have_enqueued_job(APIEntreprise::ExtraitKbisJob)
      end
    end

    context 'when the SIRET is valid but unknown' do
      let(:api_etablissement_status) { 404 }

      it { is_expected.to be_external_error }
    end

    context 'when the API answers 200 with a body we cannot read' do
      let(:api_etablissement_body) { '{"meta":{}}' }

      before { allow(Sentry).to receive(:capture_exception) }

      it 'degrades instead of stranding the champ in fetching' do
        expect(subject).to be_degraded
      end
    end
  end

  describe 'cloning a champ that already holds its data' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:siret) { '30613890001294' }

    before do
      dossier.champ_data.first.update!(etablissement: create(:etablissement, siret:), value: siret, external_id: siret)
      dossier.champ_data.first.update_columns(external_state: 'fetched')
    end

    it 'does not ask API Entreprise again' do
      expect { dossier.clone }.not_to have_enqueued_job(APIEntreprise::ExtraitKbisJob)
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
