# frozen_string_literal: true

describe APIEntrepriseService do
  describe '#perform_later_fetch_jobs' do
    let(:etablissement) { dossiers.avec_siret.etablissement }

    subject { APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedures.entreprise.id, users.usager.id) }

    before { allow_any_instance_of(APIEntrepriseToken).to receive(:roles).and_return(roles) }

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
  end
end
