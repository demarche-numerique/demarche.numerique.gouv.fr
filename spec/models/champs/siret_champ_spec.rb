# frozen_string_literal: true

describe Champs::SiretChamp do
  include Logic

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

      it 'does not block submission (pending is non-blocking)' do
        expect(subject.errors).to be_empty
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

    context 'when external fetch failed with a technical error' do
      let(:external_id) { "12345678901245" }
      let(:exception) { ExternalDataException.new(error: 'API down', code: 503) }

      before do
        champ.update_columns(
          external_state: 'external_error',
          fetch_external_data_exceptions: [exception]
        )
      end

      it 'does not block submission (technical error is non-blocking)' do
        expect(subject.errors).to be_empty
      end
    end

    context 'with a degraded-mode etablissement and no depending condition' do
      let(:external_id) { "12345678901245" }
      let(:etablissement) { Etablissement.new(siret: external_id) }

      before { champ.update_columns(external_state: 'fetched') }

      it { is_expected.to be_valid }
    end

    context 'in degraded state when the champ feeds a condition' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }, { type: :text }]) }
      let(:champ) { dossier.champ_data.find(&:siret?).tap { _1.update(external_id:, etablissement:) } }
      let(:external_id) { "12345678901245" }
      let(:etablissement) { Etablissement.new(siret: external_id) }

      before do
        champ.update_columns(external_state: 'degraded')
        siret_tdc = procedure.draft_revision.type_de_champs_for(scope: :public).first
        text_tdc = procedure.draft_revision.type_de_champs_for(scope: :public).second
        naf_column = siret_tdc.columns(procedure_id: procedure.id).find { _1.label.match?(/NAF/i) }
        text_tdc.update!(condition: ds_eq(champ_column_value(naf_column), constant('4950Z')))
      end

      it 'blocks submission until the backfill completes the etablissement' do
        expect(subject.errors[:external_id]).to include(I18n.t('activerecord.errors.messages.api_response_pending'))
      end
    end
  end

  describe '#mandatory_blank?' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret, mandatory: true }]) }
    let(:external_id) { "12345678901245" }

    context 'when the fetch is pending' do
      before { champ.update_columns(external_state: 'waiting_for_job') }

      it 'is not mandatory_blank (a syntactically valid SIRET is enough while pending)' do
        expect(champ.mandatory_blank?).to be false
      end
    end

    context 'when the fetch failed with a technical error' do
      let(:exception) { ExternalDataException.new(error: 'API down', code: 503) }

      before do
        champ.update_columns(
          external_state: 'external_error',
          fetch_external_data_exceptions: [exception]
        )
      end

      it 'is not mandatory_blank (a syntactically valid SIRET is enough despite the technical error)' do
        expect(champ.mandatory_blank?).to be false
      end
    end

    context 'when the format is invalid' do
      let(:external_id) { "12345" }

      it 'is mandatory_blank' do
        expect(champ.mandatory_blank?).to be true
      end
    end
  end

  describe '.fetch_external_data' do
    let(:api_etablissement_status) { 200 }
    let(:api_etablissement_body) { File.read('spec/fixtures/files/api_entreprise/etablissements.json') }
    let(:token_expired) { false }
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let!(:champ) { dossier.champ_data.first.tap { _1.update!(etablissement: create(:etablissement), external_id: siret, external_state: 'waiting_for_job') } }

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

      it 'returns a degraded failure carrying the stub (no retry loop, backfill jobs are scheduled)' do
        result = fetch_external_data
        expect(result).to be_failure
        expect(result.failure[:degraded]).to be true
        expect(result.failure[:etablissement]).to be_as_degraded_mode
      end

      it 'puts the champ in the degraded state' do
        champ.update_columns(external_state: 'fetching')
        champ.send(:handle_result, fetch_external_data)

        expect(champ.reload).to be_degraded
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

  describe '#fetch_external_data (result mapping)' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }
    before { champ.update_column(:external_id, '12345678901234') }

    context 'when API returns not_found' do
      before do
        allow(APIEntrepriseService).to receive(:create_etablissement_with_fallback)
          .and_return(Dry::Monads::Failure(type: :not_found, code: 404, retryable: false))
      end

      it 'wraps as a non-retryable 404 failure' do
        result = champ.fetch_external_data
        expect(result).to be_failure
        expect(result.failure[:code]).to eq(404)
        expect(result.failure[:retryable]).to be_falsey
      end
    end

    context 'when API returns a generic technical failure' do
      before do
        allow(APIEntrepriseService).to receive(:create_etablissement_with_fallback)
          .and_return(Dry::Monads::Failure(type: :network, code: 503, retryable: true))
      end

      it 'keeps the failure code' do
        expect(champ.fetch_external_data.failure[:code]).to eq(503)
      end
    end

    [422, 451].each do |status|
      context "when API returns #{status}" do
        let(:api_failure) { Dry::Monads::Failure(type: :unprocessable, code: status, retryable: false, raw_response: nil) }
        before do
          allow(APIEntrepriseService).to receive(:create_etablissement_with_fallback).and_return(api_failure)
        end

        it 'blocks submission instead of degrading' do
          result = champ.fetch_external_data
          expect(result).to be_failure
          expect(result.failure[:degraded]).to be_nil
          expect(result.failure[:code]).to eq(status)
        end
      end
    end

    context 'when the service falls back to degraded mode' do
      let(:etablissement) { instance_double(Etablissement) }
      before do
        allow(APIEntrepriseService).to receive(:create_etablissement_with_fallback)
          .and_return(Dry::Monads::Failure(degraded: true, etablissement:, type: :service_unavailable, code: 503))
      end

      it 'forwards the stub as a degraded failure (data will be backfilled later)' do
        result = champ.fetch_external_data
        expect(result).to be_failure
        expect(result.failure[:degraded]).to be true
        expect(result.failure[:etablissement]).to eq(etablissement)
      end
    end
  end

  describe '#handle_exhausted_external_data_retries!' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }]) }
    let(:dossier) { create(:dossier, procedure:) }
    let(:champ) { dossier.champ_data.first }

    before do
      champ.update_columns(
        external_id: '41816609600051',
        external_state: 'waiting_for_job',
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'boom', code: 503)]
      )
    end

    it 'converges to the degraded state instead of external_error' do
      expect { champ.handle_exhausted_external_data_retries! }
        .to have_enqueued_job(APIEntreprise::EtablissementJob)

      champ.reload
      expect(champ).to be_degraded
      expect(champ.etablissement).to be_as_degraded_mode
    end
  end

  describe '#permissive_external_data_validation?' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :siret }, { type: :text }]) }
    let(:champ) { dossier.champ_data.find(&:siret?) }

    it 'is permissive by default' do
      expect(champ.permissive_external_data_validation?).to be true
    end

    context 'when another champ has a condition based on a column of the siret champ' do
      before do
        siret_tdc = procedure.draft_revision.type_de_champs_for(scope: :public).first
        text_tdc = procedure.draft_revision.type_de_champs_for(scope: :public).second
        naf_column = siret_tdc.columns(procedure_id: procedure.id).find { _1.label.match?(/NAF/i) }
        text_tdc.update!(condition: ds_eq(champ_column_value(naf_column), constant('4950Z')))
      end

      it 'restores the blocking validation' do
        expect(champ.permissive_external_data_validation?).to be false
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
