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
      scope_without(:none).order(updated_at: :desc)
    end

    def total_count
      dossiers.count
    end

    def counts
      {
        procedure_ids:  count_procedure_ids,
        states:         count_states,
        alerts:         count_alerts,
        shared_with_me: scope_without(:shared_with_me).where(id: @user.dossiers_invites.visible_by_user).count
      }
    end

    def active_filter_tags
      tags = []
      if @params[:procedure_id].present?
        procedure = Procedure.find_by(id: @params[:procedure_id])
        tags << { group: :procedure_id, value: @params[:procedure_id].to_s, label: procedure&.libelle.to_s }
      end
      if shared_with_me?
        tags << { group: :shared_with_me, value: '1', label: I18n.t('dossiers.user_filter_panel_component.shared_with_me', default: 'Partagé avec moi') }
      end
      Array(@params[:state]).each do |s|
        tags << { group: :state, value: s, label: I18n.t("dossiers.user_filter_panel_component.states.#{s}", default: s) }
      end
      Array(@params[:alert]).each do |a|
        tags << { group: :alert, value: a, label: I18n.t("dossiers.user_filter_panel_component.alerts.#{a}", default: a) }
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
      @params[:procedure_id].present? ||
        shared_with_me? ||
        Array(@params[:state]).any? ||
        Array(@params[:alert]).any? ||
        from_created_at_date.present? ||
        from_depose_at_date.present?
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

    def count_procedure_ids
      scope_without(:procedure_id).joins(:procedure).group('procedures.id').count
    end

    def count_states
      scope = scope_without(:state)
      Users::DossierStateMapping::UI_STATES.index_with do |ui_state|
        scope.where(state: Users::DossierStateMapping.model_state_for(ui_state)).count
      end
    end

    def count_alerts
      scope = scope_without(:alert)
      ALERT_SCOPES.keys.index_with do |alert_key|
        scope.where(id: Dossier.public_send(ALERT_SCOPES[alert_key]).pluck(:id)).count
      end
    end

    def scope_without(group)
      scope = base_scope
      scope = scope.joins(:procedure).where(procedures: { id: @params[:procedure_id] }) if @params[:procedure_id].present? && group != :procedure_id
      scope = scope.where(id: @user.dossiers_invites.visible_by_user) if shared_with_me? && group != :shared_with_me
      scope = scope.where(state: model_states) if model_states.any? && group != :state
      scope = scope.where(id: alert_ids) if alert_scopes.any? && group != :alert
      scope = scope.where('dossiers.created_at >= ?', from_created_at_date) if from_created_at_date && group != :from_created_at_date
      scope = scope.where('dossiers.depose_at >= ?', from_depose_at_date) if from_depose_at_date && group != :from_depose_at_date
      scope
    end
  end
end
