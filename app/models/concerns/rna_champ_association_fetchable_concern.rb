# frozen_string_literal: true

module RNAChampAssociationFetchableConcern
  extend ActiveSupport::Concern
  include Dry::Monads[:result]

  # Pure side-effect: persists the fetched association (or a structured
  # exception) on the record. The caller must rely on the persisted state /
  # validations, not on a return value.
  #
  # APIEntreprise::Adapter#to_params maps a 404 (unknown RNA) to Success({}),
  # so a "not found" never reaches the Failure branch: an empty Success is the
  # :not_found case, while any Failure is a genuine technical error.
  def fetch_association!(rna)
    value = rna
    case APIEntreprise::RNAAdapter.new(rna, procedure_id).to_params
    in Success(data) if data.present?
      update_external_data!(data:, value:)
    in Success(_)
      update_external_data!(data: nil, value:)
      record_external_data_exception(error: :not_found, code: 404, kind: :not_found)
    in Failure(code:, retryable: true, **) => result if !APIEntreprise::HealthChecker.provider_up?(:djepva_association)
      update_external_data!(data: nil, value:)
      record_external_data_exception(error: result.failure, code:, kind: :technical_error)
    in Failure(code:, **) => result
      update_external_data!(data: nil, value:)
      record_external_data_exception(error: result.failure, code:, kind: :technical_error)
      APIEntrepriseService.report_error(result.failure, dossier_id:, rna:)
    end
    nil
  end

  private

  def record_external_data_exception(error:, code:, kind:)
    exceptions = fetch_external_data_exceptions || []
    exceptions << ExternalDataException.new(error: error.inspect, code:, kind:)
    update_columns(fetch_external_data_exceptions: exceptions)
  end
end
