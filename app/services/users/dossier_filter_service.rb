# frozen_string_literal: true

module Users
  class DossierFilterService
    ALLOWED_PARAMS = [:search, :procedure_id, :shared_with_me, :from_created_at_date, :from_depose_at_date, state: [], alert: []].freeze

    ALERT_SCOPES = {
      'nouveau_message'                 => :with_unread_messages_for_user,
      'message_avec_attente_de_reponse' => :with_pending_responses,
      'a_corriger'                      => :with_pending_corrections,
      'expire_bientot'                  => :close_to_expiration,
    }.freeze

    USER_LIST_PRELOADS = [
      :user,
      :invites,
      :transfer,
      :pending_corrections,
      :awaiting_responses,
      :individual,
      :etablissement,
      { procedure: :replaced_by_procedure },
    ].freeze

    def initialize(user:, params:)
      @user = user
      @params = params.respond_to?(:permit) ? params.permit(*ALLOWED_PARAMS) : ActionController::Parameters.new(params).permit(*ALLOWED_PARAMS)
    end

    def base_scope
      @base_scope ||=
        if search_terms.blank?
          user_dossiers
        else
          user_dossiers.merge(DossierSearchService.matching_dossiers_for_user(search_terms, @user))
        end
    end

    def dossiers
      scope_without(:none).includes(*USER_LIST_PRELOADS).order(updated_at: :desc)
    end

    def total_count
      dossiers.count
    end

    def counts
      {
        procedure_ids:  count_procedure_ids,
        states:         count_states,
        alerts:         count_alerts,
        shared_with_me: scope_without(:shared_with_me).where(id: @user.dossiers_invites.visible_by_user).count,
      }
    end

    def active_filter_tags
      tags = []
      if @params[:procedure_id].present? && (procedure = filtered_procedure)
        tags << { group: :procedure_id, value: @params[:procedure_id].to_s, label: procedure.libelle }
      end
      if shared_with_me?
        tags << { group: :shared_with_me, value: '1', label: I18n.t('views.users.dossiers.index.filter_panel.groups.shared_with_me') }
      end
      Array(@params[:state]).each do |s|
        tags << { group: :state, value: s, label: Users::DossierStateMapping.state_label(s) }
      end
      Array(@params[:alert]).each do |a|
        tags << { group: :alert, value: a, label: I18n.t("views.users.dossiers.index.filter_panel.alerts.#{a}") }
      end
      if from_created_at_date
        tags << { group: :from_created_at_date, value: @params[:from_created_at_date], label: @params[:from_created_at_date].to_s }
      end
      if from_depose_at_date
        tags << { group: :from_depose_at_date, value: @params[:from_depose_at_date], label: @params[:from_depose_at_date].to_s }
      end
      tags
    end

    def active?
      active_filter_tags.any?
    end

    private

    def user_dossiers
      invited_ids = @user.dossiers_invites.visible_by_user.pluck(:id)
      own = @user.dossiers.visible_by_user
      return own if invited_ids.empty?
      own.or(Dossier.visible_by_user.where(id: invited_ids))
    end

    def filtered_procedure
      Procedure
        .where(id: @params[:procedure_id])
        .where(id: user_dossiers.joins(:procedure).select('procedures.id'))
        .first
    end

    def search_terms
      @params[:search].presence
    end

    def shared_with_me?
      ActiveModel::Type::Boolean.new.cast(@params[:shared_with_me])
    end

    def model_states
      Array(@params[:state])
    end

    def alert_scopes
      Array(@params[:alert]).filter_map { |a| ALERT_SCOPES[a] }
    end

    def alert_subquery
      @alert_subquery ||= alert_scopes
        .map { |scope_name| Dossier.where(id: bounded_alert_subquery(scope_name)) }
        .reduce { |combined, rel| combined.or(rel) }
    end

    def bounded_alert_subquery(scope_name)
      base_scope.unscope(:order).merge(Dossier.public_send(scope_name)).select(:id)
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

    def count_procedure_ids
      scope_without(:procedure_id).reorder(nil).joins(:procedure).group('procedures.id').count
    end

    def count_states
      scope = scope_without(:state)
      Users::DossierStateMapping::UI_STATES.index_with do |state|
        scope.where(state: state).count
      end
    end

    def count_alerts
      scope = scope_without(:alert)
      ALERT_SCOPES.keys.index_with do |alert_key|
        scope.where(id: bounded_alert_subquery(ALERT_SCOPES[alert_key])).count
      end
    end

    def scope_without(group)
      scope = base_scope
      scope = scope.joins(:procedure).where(procedures: { id: @params[:procedure_id] }) if @params[:procedure_id].present? && group != :procedure_id
      scope = scope.where(id: @user.dossiers_invites.visible_by_user) if shared_with_me? && group != :shared_with_me
      scope = scope.where(state: model_states) if model_states.any? && group != :state
      scope = scope.where(id: alert_subquery) if alert_scopes.any? && group != :alert
      scope = scope.where(dossiers: { created_at: from_created_at_date.. }) if from_created_at_date && group != :from_created_at_date
      scope = scope.where(dossiers: { depose_at: from_depose_at_date.. }) if from_depose_at_date && group != :from_depose_at_date
      scope
    end
  end
end
