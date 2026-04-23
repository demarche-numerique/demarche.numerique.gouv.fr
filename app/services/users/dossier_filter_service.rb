# frozen_string_literal: true

module Users
  class DossierFilterService
    ALLOWED_PARAMS = [:search, :procedure_id, :shared_with_me, :from_created_at_date, :from_depose_at_date, state: [], alert: []].freeze

    ALERT_SCOPES = {
      'nouveau_message'                 => :with_unread_messages_for_user,
      'message_avec_attente_de_reponse' => :with_pending_responses,
      'a_corriger'                      => :with_pending_corrections,
      'expire_bientot'                  => :close_to_expiration
    }.freeze

    def initialize(user:, params:)
      @user = user
      @params = params.respond_to?(:permit) ? params.permit(*ALLOWED_PARAMS) : ActionController::Parameters.new(params).permit(*ALLOWED_PARAMS)
    end

    def base_scope
      scope = Dossier.where(id: @user.dossiers.visible_by_user).or(
        Dossier.where(id: @user.dossiers_invites.visible_by_user)
      )
      return scope if search_terms.blank?

      scope.merge(DossierSearchService.matching_dossiers_for_user(search_terms, @user))
    end

    def dossiers
      scope = base_scope
      scope = scope.joins(:procedure).where(procedures: { id: @params[:procedure_id] }) if @params[:procedure_id].present?
      scope = scope.where(id: @user.dossiers_invites.visible_by_user) if shared_with_me?
      scope = scope.where(state: model_states) if model_states.any?
      scope = scope.where(id: alert_ids) if alert_scopes.any?
      scope = scope.where('dossiers.created_at >= ?', from_created_at_date) if from_created_at_date
      scope = scope.where('dossiers.depose_at >= ?', from_depose_at_date) if from_depose_at_date
      scope.order(updated_at: :desc)
    end

    private

    def search_terms
      @params[:search].presence
    end

    def shared_with_me?
      ActiveModel::Type::Boolean.new.cast(@params[:shared_with_me])
    end

    def model_states
      Array(@params[:state])
        .map { |s| Users::DossierStateMapping.model_state_for(s) }
        .compact
    end

    def alert_scopes
      Array(@params[:alert]).map { |a| ALERT_SCOPES[a] }.compact
    end

    def alert_ids
      alert_scopes.flat_map { |scope_name| Dossier.public_send(scope_name).pluck(:id) }.uniq
    end

    def from_created_at_date
      parse_date(@params[:from_created_at_date])
    end

    def from_depose_at_date
      parse_date(@params[:from_depose_at_date])
    end

    def parse_date(raw)
      return nil if raw.blank?
      Date.parse(raw)
    rescue Date::Error
      nil
    end
  end
end
