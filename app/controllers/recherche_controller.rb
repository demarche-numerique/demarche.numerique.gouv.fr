# frozen_string_literal: true

class RechercheController < ApplicationController
  before_action :authenticate_logged_user!
  ITEMS_PER_PAGE = 25

  # the columns are generally procedure specific
  # but in the search context, we are looking for dossiers from multiple procedures
  # so we are faking the columns with a random procedure_id
  PROJECTIONS = [
    Column.new(procedure_id: 666, table: 'procedure', column: 'libelle'),
    Column.new(procedure_id: 666, table: 'user', column: 'email'),
    Column.new(procedure_id: 666, table: 'procedure', column: 'procedure_id'),
  ]

  def nav_bar_profile
    return super if request.blank? # Controller introspection does not contains params/request, see NavBarProfileConcern

    context_params = params[:context]&.to_sym
    case context_params
    when :instructeur, :expert
      context_params
    else
      :user
    end
  end

  def index
    @search_terms = search_terms
    @dossiers_count = 0

    return if handle_special_cases

    @instructeur_dossiers_ids = DossierSearchService
      .matching_dossiers(current_instructeur&.dossiers, @search_terms, with_annotation: true)

    expert_dossier_ids = DossierSearchService
      .matching_dossiers(current_expert&.dossiers, @search_terms)

    matching_dossiers_ids = (@instructeur_dossiers_ids + expert_dossier_ids).uniq

    @paginated_ids = Kaminari
      .paginate_array(matching_dossiers_ids)
      .page(page)
      .per(ITEMS_PER_PAGE)

    @projected_dossiers = DossierProjectionService.project(@paginated_ids, PROJECTIONS)

    @dossiers_count = matching_dossiers_ids.count
    @followed_dossiers_id = current_instructeur&.followed_dossiers&.where(id: @paginated_ids)&.ids || []
    @dossier_avis_ids_h = current_expert&.avis&.where(dossier_id: @paginated_ids)&.pluck(:dossier_id, :id).to_h || {}
    @notifications = instructeur_signed_in? ? DossierNotification.notifications_for_instructeur_dossiers(current_instructeur, @paginated_ids) : {}

  rescue ActiveRecord::QueryCanceled => e
    Sentry.capture_exception(e)

    logger = Lograge.logger || Rails.logger

    payload = {
      message: 'search timeout',
      user_id: current_user.id,
      request_id: Current.request_id,
      controller: self.class.name,
      terms: @search_terms,
    }

    logger.info(payload.to_json)

    redirect_to recherche_index_path, alert: "La recherche n’a pas pu aboutir."
  end

  private

  def page
    params[:page].presence || 1
  end

  def search_terms
    params[:q]
  end

  def handle_special_cases
    return false unless instructeur_signed_in? && DossierSearchService.id_compatible?(@search_terms)

    @deleted_dossier = current_instructeur.deleted_dossiers.find_by(dossier_id: @search_terms)
    return true if @deleted_dossier.present?

    dossier = Dossier.state_not_brouillon.find_by(id: @search_terms)
    return false if dossier.nil?

    if current_instructeur.groupe_instructeur_ids.include?(dossier.groupe_instructeur_id)
      @hidden_dossier = dossier.hidden_by_administration? ? dossier : nil
      return true if @hidden_dossier.present?
    else
      @dossier_not_in_instructor_group = current_instructeur.procedures.include?(dossier.procedure) ? dossier : nil
      return true if @dossier_not_in_instructor_group.present?
    end

    false
  end
end
