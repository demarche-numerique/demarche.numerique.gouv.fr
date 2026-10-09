# frozen_string_literal: true

RSpec.describe DemandeurSiret do
  let(:siret) { '30613890001294' }
  let(:api_etablissement_status) { 200 }
  let(:dossier) { create(:dossier, procedure: procedures.entreprise) }
  let(:demandeur_siret) { DemandeurSiret.create!(dossier:, siret:) }

  before do
    procedures.entreprise.update!(api_entreprise_token: JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none'))
    stub_request(:get, /https:\/\/entreprise.api.gouv.fr\/v4\/insee\/sirene\/etablissements\/#{siret}/)
      .to_return(status: api_etablissement_status, body: Rails.root.join('spec/fixtures/files/api_entreprise/etablissements.json').read)
    allow_any_instance_of(APIEntrepriseToken).to receive(:roles)
      .and_return(["attestations_fiscales", "attestations_sociales", "bilans_entreprise_bdf"])
  end

  describe '.submit!' do
    subject(:submit) { DemandeurSiret.submit!(dossier, siret) }

    context 'when the API answers' do
      it 'attaches the etablissement and keeps no unverified SIRET' do
        expect(submit).to eq(:verified)
        expect(dossier.reload.etablissement.siret).to eq(siret)
        expect(DemandeurSiret.where(dossier:)).to be_empty
      end
    end

    context 'when the API does not answer' do
      let(:api_etablissement_status) { 503 }

      it 'keeps the SIRET unverified' do
        expect(submit).to eq(:unverified)
        expect(dossier.reload.demandeur_siret).to be_degraded
        expect(dossier.etablissement).to be_nil
      end

      context 'with the etablissement of another SIRET' do
        let!(:previous) { create(:etablissement, dossier:, siret: '41816609600051') }

        it 'drops it: the usager chose another SIRET' do
          expect(submit).to eq(:unverified)
          expect(Etablissement.where(id: previous.id)).to be_empty
        end
      end
    end

    context 'when the SIRET is unknown' do
      let(:api_etablissement_status) { 404 }

      it 'returns the code and keeps no unverified SIRET' do
        expect(submit).to eq(404)
        expect(DemandeurSiret.where(dossier:)).to be_empty
      end

      context 'with a verified etablissement' do
        let!(:previous) { create(:etablissement, dossier:, siret: '41816609600051') }

        it 'keeps it' do
          expect(submit).to eq(404)
          expect(dossier.reload.etablissement).to eq(previous)
        end
      end
    end

    context 'with a previous SIRET still waiting for the API' do
      before { DemandeurSiret.create!(dossier:, siret: '41816609600051', external_state: 'degraded') }

      it 'replaces it' do
        submit

        expect(DemandeurSiret.where(dossier:).pluck(:siret)).to be_empty
        expect(dossier.reload.etablissement.siret).to eq(siret)
      end
    end

    context 'when the usager submits the SIRET already verified' do
      before { create(:etablissement, dossier:, siret:) }

      it 'does not call the API again' do
        expect(submit).to eq(:verified)
        expect(a_request(:get, /entreprise.api.gouv.fr/)).not_to have_been_made
      end
    end
  end

  describe '#verify!' do
    subject(:verify) { demandeur_siret.verify! }

    context 'when the API answers' do
      it 'attaches the etablissement to the dossier and forgets the unverified SIRET' do
        verify

        expect(dossier.reload.etablissement.siret).to eq(siret)
        expect(DemandeurSiret.where(dossier:)).to be_empty
        expect(demandeur_siret).to be_destroyed
      end

      it 'replaces the etablissement of a previous SIRET' do
        previous = create(:etablissement, dossier:, siret: '41816609600051')

        verify

        expect(Etablissement.where(id: previous.id)).to be_empty
        expect(dossier.reload.etablissement.siret).to eq(siret)
      end

      it 'asks for the complementary data' do
        expect { verify }.to have_enqueued_job(APIEntreprise::TvaJob)
      end
    end

    context 'when the API does not answer' do
      let(:api_etablissement_status) { 503 }

      it 'is degraded, with no etablissement' do
        verify

        expect(demandeur_siret.reload).to be_degraded
        expect(dossier.reload.etablissement).to be_nil
      end
    end

    context 'when our own token is rejected' do
      let(:api_etablissement_status) { 401 }

      it 'is degraded' do
        verify

        expect(demandeur_siret.reload).to be_degraded
      end
    end

    context 'when our token is expired' do
      before { allow_any_instance_of(APIEntrepriseToken).to receive(:expired?).and_return(true) }

      it 'degrades without any call going out' do
        verify

        expect(demandeur_siret.reload).to be_degraded
        expect(a_request(:get, /entreprise.api.gouv.fr/)).not_to have_been_made
      end
    end

    context 'when the SIRET is unknown' do
      let(:api_etablissement_status) { 404 }

      it 'is an external error carrying the code' do
        verify

        expect(demandeur_siret.reload).to be_external_error
        expect(demandeur_siret.fetch_external_data_exceptions.last.code).to eq(404)
      end
    end
  end

  describe '#reset_external_data!' do
    before do
      demandeur_siret.update_columns(external_state: 'external_error',
        fetch_external_data_exceptions: [ExternalDataException.new(error: 'not found', code: 404)])
    end

    it 'puts it back at rest without its previous failure' do
      demandeur_siret.reset_external_data!

      expect(demandeur_siret.reload).to be_idle
      expect(demandeur_siret.fetch_external_data_exceptions).to be_empty
    end
  end

  describe '#may_fix_degraded?' do
    before { demandeur_siret.update_columns(external_state: 'degraded') }

    it { expect(demandeur_siret.may_fix_degraded?).to be true }

    context 'while the token of the procedure is rejected' do
      before { procedures.entreprise.update!(api_entreprise_token_rejected_at: Time.current) }

      it { expect(demandeur_siret.reload.may_fix_degraded?).to be false }
    end
  end
end
