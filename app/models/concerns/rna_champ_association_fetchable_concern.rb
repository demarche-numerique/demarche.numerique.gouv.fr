# frozen_string_literal: true

module RNAChampAssociationFetchableConcern
  extend ActiveSupport::Concern

  def fetch_association!(rna)
    value = rna
    data = APIEntreprise::RNAAdapter.new(rna, procedure_id).to_params
    update_external_data!(data:, value:)
    valid_champ_value?
  rescue APIEntreprise::API::Error, APIEntrepriseToken::TokenError => error
    update_external_data!(data: nil, value:)
    if APIEntrepriseService.service_unavailable_error?(error, target: :djepva)
      errors.add(:value, :network_error)
    else
      Sentry.capture_exception(error, extra: { dossier_id:, rna: })
    end
    false
  end
end
