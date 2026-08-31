# frozen_string_literal: true

describe APIEntrepriseService do
  shared_examples 'schedule fetch of all etablissement params' do
    [
      APIEntreprise::ExtraitKbisJob, APIEntreprise::TvaJob,
      APIEntreprise::AssociationJob, APIEntreprise::ExercicesJob,
      APIEntreprise::EffectifsJob, APIEntreprise::EffectifsAnnuelsJob, APIEntreprise::AttestationSocialeJob,
      APIEntreprise::BilansBdfJob,
    ].each do |job|
      it "should enqueue #{job.class.name}" do
        expect { subject }.to have_enqueued_job(job)
      end
    end
  end

  describe '#create_etablissement' do
    before do
      stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
        .to_return(body: etablissements_body, status: etablissements_status)
    end

    let(:siret) { '30613890001294' }
    let(:raison_sociale) { "DIRECTION INTERMINISTERIELLE DU NUMERIQUE" }
    let(:etablissements_status) { 200 }
    let(:etablissements_body) { File.read('spec/fixtures/files/api_entreprise/etablissements.json') }
    let(:valid_token) { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" }
    let(:procedure) { create(:procedure, api_entreprise_token: valid_token) }
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:subject) { APIEntrepriseService.create_etablissement(dossier, siret, procedure.id) }

    before do
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles).and_return([])
      allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
    end

    context 'when service is up' do
      it 'should fetch etablissement params' do
        expect(subject).to be_success
        expect(subject.value!.siret).to eq(siret)
      end

      it 'should fetch entreprise params' do
        expect(subject.value!.entreprise_raison_sociale).to eq(raison_sociale)
      end

      it_behaves_like 'schedule fetch of all etablissement params'
    end

    context 'when etablissement api down' do
      let(:etablissements_status) { 504 }
      let(:etablissements_body) { '' }

      it 'should return a Failure' do
        expect(subject).to be_failure
        expect(subject.failure[:retryable]).to be true
      end
    end

    context 'when etablissement not found' do
      let(:etablissements_status) { 404 }
      let(:etablissements_body) { '' }

      it 'should return Failure with type :not_found' do
        expect(subject).to be_failure
        expect(subject.failure).to include(type: :not_found, code: 404, retryable: false)
      end
    end

    context 'when API returns 429 (rate limit)' do
      let(:etablissements_status) { 429 }
      let(:etablissements_body) { '{"errors":[]}' }

      it 'returns Failure with retryable flag instead of silently losing data' do
        expect(subject).to be_failure
        expect(subject.failure[:code]).to eq(429)
        expect(subject.failure[:retryable]).to be true
      end
    end

    context 'when API returns 451 (non-diffusable entity)' do
      let(:etablissements_status) { 451 }
      let(:etablissements_body) { '' }

      it 'returns Failure with unavailable_for_legal_reasons type' do
        expect(subject).to be_failure
        expect(subject.failure[:type]).to eq(:unavailable_for_legal_reasons)
        expect(subject.failure[:retryable]).to be false
      end
    end
  end

  describe '#create_etablissement_as_degraded_mode' do
    let(:siret) { '41816609600051' }
    let(:procedure) { create(:procedure) }
    let(:dossier) { create(:dossier, procedure: procedure) }
    let(:user_id) { 12 }

    subject(:etablissement) { APIEntrepriseService.create_etablissement_as_degraded_mode(dossier, siret, user_id) }

    it 'should create an etablissement with minimumal attributes' do
      etablissement = subject

      expect(etablissement.siret).to eq(siret)
      expect(etablissement).to be_as_degraded_mode
    end

    it_behaves_like 'schedule fetch of all etablissement params'
  end

  describe '#create_etablissement_with_fallback' do
    let(:siret) { '30613890001294' }
    let(:valid_token) { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" }
    let(:procedure) { create(:procedure, api_entreprise_token: valid_token) }
    let(:dossier) { create(:dossier, procedure: procedure) }

    before do
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles).and_return([])
      allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(false)
    end

    subject { APIEntrepriseService.create_etablissement_with_fallback(dossier, siret) }

    context 'when API succeeds' do
      before do
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
          .to_return(body: File.read('spec/fixtures/files/api_entreprise/etablissements.json'), status: 200)
      end

      it 'returns Success with etablissement' do
        expect(subject).to be_success
        expect(subject.value!.siret).to eq(siret)
      end
    end

    context 'when API is down and degraded mode activates' do
      before do
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
          .to_return(body: '', status: 503)
        allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:insee_sirene).and_return(false)
      end

      it 'returns Success with degraded etablissement' do
        expect(subject).to be_success
        expect(subject.value!.siret).to eq(siret)
        expect(subject.value!).to be_as_degraded_mode
      end
    end

    context 'when API is down but degraded mode does not activate' do
      before do
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
          .to_return(body: '', status: 503)
        allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:insee_sirene).and_return(true)
      end

      it 'returns the original Failure' do
        expect(subject).to be_failure
        expect(subject.failure[:retryable]).to be true
      end
    end

    context 'when API returns 429 (rate limited)' do
      before do
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
          .to_return(body: '', status: 429)
      end

      it 'falls back to degraded mode without checking provider health' do
        expect(APIEntreprise::HealthChecker).not_to receive(:provider_up?)
        expect(subject).to be_success
        expect(subject.value!.siret).to eq(siret)
        expect(subject.value!).to be_as_degraded_mode
      end
    end

    context 'when API returns 451' do
      before do
        stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
          .to_return(body: '', status: 451)
      end

      it 'returns Failure without fallback' do
        expect(subject).to be_failure
        expect(subject.failure[:type]).to eq(:unavailable_for_legal_reasons)
      end
    end
  end

  describe '#update_etablissement_from_degraded_mode' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:etablissement) { create(:etablissement, adresse: nil, siret: '01234567891011') }

    before do
      allow_any_instance_of(APIEntreprise::EtablissementAdapter).to receive(:to_params)
        .and_return(Dry::Monads::Success(adresse: '7 rue du puits, coye la foret'))
    end

    context 'when the etablissement belongs to a degraded champ' do
      before do
        champ.update_columns(etablissement_id: etablissement.id, external_state: 'degraded')
      end

      it 'completes the data and leaves the degraded state' do
        described_class.update_etablissement_from_degraded_mode(etablissement, procedure.id)

        expect(etablissement.reload.adresse).to eq('7 rue du puits, coye la foret')
        expect(champ.reload).to be_fetched
      end
    end

    context 'when the etablissement belongs to a dossier (no champ)' do
      let!(:dossier_with_etablissement) { create(:dossier, :en_construction, etablissement:) }

      it 'completes the data without raising' do
        expect { described_class.update_etablissement_from_degraded_mode(etablissement, procedure.id) }
          .to change { etablissement.reload.adresse }.from(nil).to('7 rue du puits, coye la foret')
      end
    end
  end

  describe '#report_error' do
    it 'sends a message to Sentry with context' do
      failure = { type: :server_error, code: 503, retryable: true, raw_response: nil }

      expect(Sentry).to receive(:capture_message).with(
        "API Entreprise error: server_error",
        level: :error,
        extra: { dossier_id: 42, code: 503, raw_body: nil }
      )

      APIEntrepriseService.report_error(failure, dossier_id: 42)
    end

    it 'truncates raw_body from response' do
      raw_response = double(body: "x" * 2000)
      failure = { type: :timeout, code: 0, retryable: true, raw_response: }

      expect(Sentry).to receive(:capture_message).with(
        "API Entreprise error: timeout",
        level: :error,
        extra: hash_including(raw_body: a_string_matching(/\.\.\.$/))
      )

      APIEntrepriseService.report_error(failure, siret: '123')
    end
  end
end
