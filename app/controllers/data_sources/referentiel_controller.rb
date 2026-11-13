# frozen_string_literal: true

class DataSources::ReferentielController < DataSources::BaseController
  before_action :mark_as_retryable, :set_dossier, :referentiel, :referentiel_service
  MIN_QUERY_LENGTH = 3
  MAX_QUERY_SIZE = 100

  def search
    if query && params[:referentiel_id].present?
      return render json: [] if !referentiel&.autocomplete_ready?

      begin
        result = referentiel_service.call(query, dossier: dossier_on_edit_stream, row_id: params[:row_id].presence)

        case result
        in Dry::Monads::Success
          formatted = ReferentielAutocompleteRenderService.new(result.value!, referentiel).format_response
          return render json: formatted
        in Dry::Monads::Failure(data) if data[:retryable]
          raise RetryableError if @retryable
          Sentry.set_extras(body: data[:body], code: data[:code]) if data.is_a?(Hash)
          Sentry.capture_message("Referentiel API retryable failure")
        in Dry::Monads::Failure(data)
          Sentry.set_extras(body: data[:body], code: data[:code]) if data.is_a?(Hash)
          Sentry.capture_message("Referentiel API failure")
        end
      rescue RetryableError
        @retryable = false
        retry
      rescue StandardError => e
        Sentry.capture_exception(e)
      end
    end
    render json: []
  end

  private

  def authenticate_data_source_user!
    authenticate_user!
  end

  def mark_as_retryable
    @retryable = true
  end

  def referentiel_service
    @referentiel_service ||= ReferentielService.new(referentiel: referentiel, timeout:)
  end

  def timeout
    ReferentielService::API_TIMEOUT / 2 # due to retry
  end

  def query
    return nil if params[:q].blank?
    return nil if params[:q].length < MIN_QUERY_LENGTH
    return nil if params[:q].length > MAX_QUERY_SIZE

    @query ||= params[:q].strip
  end

  def referentiel
    return @referentiel if defined?(@referentiel)

    @referentiel = authorized_referentiel
  end

  def authorized_referentiel
    return nil if @dossier.nil? || params[:referentiel_id].blank?

    candidate = Referentiel.find_by(id: params[:referentiel_id])
    return nil if candidate.nil?

    @type_de_champ = @dossier.revision.type_de_champs.find { it.referentiel_id == candidate.id }
    candidate if @type_de_champ.present? && (@type_de_champ.public? || can_update_annotations?)
  end

  # Les annotations privées sont remplies par l'instructeur, et par l'administrateur
  # dans l'aperçu de sa démarche.
  def can_update_annotations?
    @dossier.for_procedure_preview? || current_user.instructeur&.dossiers&.exists?(id: @dossier.id)
  end

  # L'usager remplit le formulaire sur un stream de brouillon : les tags de l'URL doivent
  # être résolus sur les valeurs qu'il vient de saisir, pas sur celles du stream principal.
  def dossier_on_edit_stream
    return nil if @dossier.nil?

    @dossier.with_update_stream(current_user) if @type_de_champ&.public?
    @dossier
  end

  def set_dossier
    return if params[:dossier_id].blank?

    # The URL tags take the dossier's champ values: a dossier requiring FranceConnect+ lends them
    # to a session that may open it only
    usager_dossier = current_user.dossiers.find_by(id: params[:dossier_id])
    usager_dossier = nil if usager_dossier&.france_connect_plus_missing?(Current.user_session)

    @dossier = usager_dossier || current_user.instructeur&.dossiers&.find_by(id: params[:dossier_id])

    DossierPreloader.load_one(@dossier) if @dossier
  end

  class RetryableError < StandardError; end
end
