# frozen_string_literal: true

describe APIEntrepriseService do
  describe '#perform_later_fetch_jobs' do
    let(:etablissement) { dossiers.avec_siret.etablissement }

    subject { APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedures.entreprise.id, users.usager.id) }

    before do
      allow_any_instance_of(APIEntrepriseToken).to receive(:roles).and_return(roles)
      allow(APIEntreprise::HealthChecker).to receive(:provider_up?).and_return(true)
    end

    context 'when the token holds no role' do
      let(:roles) { [] }

      it 'skips the jobs gated by a role' do
        subject

        expect(APIEntreprise::AttestationSocialeJob).not_to have_been_enqueued
        expect(APIEntreprise::AttestationFiscaleJob).not_to have_been_enqueued
        expect(APIEntreprise::BilansBdfJob).not_to have_been_enqueued
      end
    end

    context 'when the token holds the roles' do
      let(:roles) { ['attestation_sociale', 'attestation_fiscale', 'bilans_entreprise_bdf'] }

      it 'enqueues the jobs gated by a role' do
        subject

        expect(APIEntreprise::AttestationSocialeJob).to have_been_enqueued
        expect(APIEntreprise::AttestationFiscaleJob).to have_been_enqueued
        expect(APIEntreprise::BilansBdfJob).to have_been_enqueued
      end
    end

    context 'with a delay' do
      let(:roles) { [] }

      it 'enqueues the jobs after it' do
        freeze_time do
          APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedures.entreprise.id, users.usager.id, wait: 10.minutes)

          expect(APIEntreprise::TvaJob).to have_been_enqueued.at(10.minutes.from_now)
        end
      end
    end

    context 'while the provider of a job is down' do
      let(:roles) { ['attestation_fiscale'] }

      before do
        allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with('dgfip/numero_tva').and_return(false)
        allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with('dgfip/attestation_fiscale').and_return(false)
      end

      it 'parks it for the cron instead of enqueuing it' do
        subject

        expect(APIEntreprise::TvaJob).not_to have_been_enqueued
        expect(APIEntreprise::AttestationFiscaleJob).not_to have_been_enqueued
        expect(ParkedAPIEntrepriseFetch.find_by(etablissement:, job: 'TvaJob'))
          .to have_attributes(code: 503, procedure_id: procedures.entreprise.id, job_arguments: [etablissement.id, procedures.entreprise.id])
        expect(ParkedAPIEntrepriseFetch.find_by(etablissement:, job: 'AttestationFiscaleJob').job_arguments)
          .to eq([etablissement.id, procedures.entreprise.id, users.usager.id])
      end

      it 'still enqueues the jobs of the other providers' do
        subject

        expect(APIEntreprise::ExercicesJob).to have_been_enqueued.with(etablissement.id, procedures.entreprise.id)
      end
    end

    context 'when the DGFIP holds no turnover for the legal form' do
      let(:roles) { [] }

      before { etablissement.update!(entreprise_forme_juridique_code: '7120') }

      it 'skips the exercices' do
        subject

        expect(APIEntreprise::ExercicesJob).not_to have_been_enqueued
        expect(APIEntreprise::TvaJob).to have_been_enqueued
      end
    end

    context 'when the legal form is not registered with the RCS' do
      let(:roles) { [] }

      before { etablissement.update!(entreprise_forme_juridique_code: '7210') }

      it 'skips the extrait Kbis' do
        subject

        expect(APIEntreprise::ExtraitKbisJob).not_to have_been_enqueued
      end
    end

    context 'when the etablissement is not an association' do
      let(:roles) { [] }

      it 'skips the RNA' do
        subject

        expect(APIEntreprise::AssociationJob).not_to have_been_enqueued
      end
    end

    context 'when the unite legale employs nobody' do
      let(:roles) { [] }

      before { etablissement.update!(entreprise_code_effectif_entreprise: 'NN') }

      it 'skips the staff counts' do
        subject

        expect(APIEntreprise::EffectifsJob).not_to have_been_enqueued
        expect(APIEntreprise::EffectifsAnnuelsJob).not_to have_been_enqueued
      end
    end
  end
end
