# frozen_string_literal: true

class APIEntrepriseService
  class << self
    include Dry::Monads[:result]

    def update_etablissement_from_degraded_mode(etablissement, procedure_id)
      case APIEntreprise::EtablissementAdapter.new(etablissement.siret, procedure_id).to_params
      in Success(etablissement_params) if etablissement_params.present?
        etablissement.update!(etablissement_params)
        etablissement.update_champ_value_json!
        etablissement
      else
        nil
      end
    end

    def perform_later_fetch_jobs(etablissement, procedure_id, user_id, wait: nil)
      token = Procedure.find(procedure_id).api_entreprise_token
      jobs = [
        APIEntreprise::TvaJob,
        APIEntreprise::EffectifsJob, APIEntreprise::EffectifsAnnuelsJob,
      ]
      jobs << APIEntreprise::ExtraitKbisJob if etablissement.extrait_kbis_fetchable?
      jobs << APIEntreprise::AssociationJob if etablissement.association_fetchable?
      jobs << APIEntreprise::ExercicesJob if etablissement.exercices_fetchable?
      jobs << APIEntreprise::AttestationSocialeJob if token.can_fetch_attestation_sociale?
      jobs << APIEntreprise::BilansBdfJob if token.can_fetch_bilans_bdf?
      if etablissement.as_degraded_mode?
        jobs << APIEntreprise::EtablissementJob
      end
      jobs.each do |job|
        job.set(wait:).perform_later(etablissement.id, procedure_id)
      end

      if token.can_fetch_attestation_fiscale?
        APIEntreprise::AttestationFiscaleJob.set(wait:).perform_later(etablissement.id, procedure_id, user_id)
      end
    end
  end
end
