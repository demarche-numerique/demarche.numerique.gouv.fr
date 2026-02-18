# frozen_string_literal: true

class Champs::QuotientFamilialChamp < Champ
  def fc_data_approved? = ActiveModel::Type::Boolean.new.cast(value)

  def fc_data_correct?
    fetched? && fc_data_approved?
  end

  def fc_data_incorrect?
    fetched? && fc_data_approved? == false
  end

  def requires_external_data?
    true
  end

  def ready_for_external_call?
    dossier.user_from_france_connect? && !dossier.for_tiers? && dossier.procedure.for_individual? && !dossier.for_procedure_preview?
  end

  def fetch_external_data
    fci = dossier.user.france_connect_informations.first
    api = APIParticulier::QuotientFamilial.new(procedure)
    api.quotient_familial(fci)
  end
end
