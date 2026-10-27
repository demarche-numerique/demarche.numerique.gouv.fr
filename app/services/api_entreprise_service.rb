# frozen_string_literal: true

class APIEntrepriseService
  class << self
    def perform_later_fetch_jobs(etablissement, procedure_id, user_id, wait: nil)
      token = Procedure.find(procedure_id).api_entreprise_token
      jobs = [APIEntreprise::TvaJob]
      jobs << APIEntreprise::ExtraitKbisJob if etablissement.extrait_kbis_fetchable?
      jobs << APIEntreprise::AssociationJob if etablissement.association_fetchable?
      jobs << APIEntreprise::ExercicesJob if etablissement.exercices_fetchable?
      jobs.push(APIEntreprise::EffectifsJob, APIEntreprise::EffectifsAnnuelsJob) if etablissement.effectifs_fetchable?
      jobs << APIEntreprise::AttestationSocialeJob if token.can_fetch_attestation_sociale?
      jobs << APIEntreprise::BilansBdfJob if token.can_fetch_bilans_bdf?
      jobs.each do |job|
        job.perform_later_or_park(etablissement.id, procedure_id, wait:)
      end

      if token.can_fetch_attestation_fiscale?
        APIEntreprise::AttestationFiscaleJob.perform_later_or_park(etablissement.id, procedure_id, user_id, wait:)
      end
    end
  end
end
