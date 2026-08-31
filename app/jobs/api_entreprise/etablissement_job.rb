# frozen_string_literal: true

class APIEntreprise::EtablissementJob < APIEntreprise::Job
  def perform(etablissement_id, procedure_id)
    find_etablissement(etablissement_id)

    case APIEntrepriseService.update_etablissement_from_degraded_mode(etablissement, procedure_id)
    in Failure(type:, **)
      raise RetryableError, "#{self.class.name}: #{type}, retrying later"
    else
      nil
    end
  end
end
