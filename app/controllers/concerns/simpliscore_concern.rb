# frozen_string_literal: true

module SimpliscoreConcern
  extend ActiveSupport::Concern

  included do
    before_action :ensure_simpliscore_enabled,
      only: [:simplify, :accept_simplification, :enqueue_simplify, :poll_simplify, :new_simplify]
    before_action :ensure_valid_tunnel,
      only: [:simplify, :enqueue_simplify, :poll_simplify, :accept_simplification]
  end

  def enqueue_simplify
    if tunnel_query.in_progress?(rule: params[:rule])
      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: params[:tunnel_id], rule: params[:rule]),
        notice: 'Une recherche est déjà en cours pour cette règle.'
    else
      LLM::ImproveProcedureJob.perform_now(
        @procedure,
        params[:tunnel_id],
        params[:rule],
        action: action_name,
        user_id: current_administrateur.user.id
      )
      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: params[:tunnel_id], rule: params[:rule]),
        notice: 'La recherche a été lancée. Vous serez prévenu(e) lorsque les suggestions seront prêtes.'
    end
  end

  def simplify
    @tunnel_id = params[:tunnel_id]

    current_suggestion = tunnel_query.find_for_rule(rule: params[:rule])

    current_step_finished = current_suggestion&.state&.in?(['accepted', 'skipped'])
    last_completed_step = tunnel_query.last_completed_step if current_step_finished
    next_rule = LLM::Rule.next_rule(last_completed_step.rule) if last_completed_step
    visiting_different_step = last_completed_step && params[:rule] != last_completed_step.rule

    if next_rule
      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: @tunnel_id, rule: next_rule)
    elsif visiting_different_step
      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: @tunnel_id, rule: last_completed_step.rule)
    else
      @llm_rule_suggestion = current_suggestion || tunnel_query.build_for_rule(rule: params[:rule])
    end
  end

  def poll_simplify
    @llm_rule_suggestion = tunnel_query.find_for_rule(rule: params[:rule])

    if @llm_rule_suggestion&.state&.in?(['completed', 'failed'])
      render turbo_stream: turbo_stream.refresh
    else
      head :no_content
    end
  end

  def accept_simplification
    @llm_rule_suggestion = tunnel_query.find_completed(id: params[:id], rule: params[:rule])

    unless @llm_rule_suggestion
      redirect_to new_simplify_admin_procedure_types_de_champ_path(@procedure), alert: "Suggestion non trouvée"
      return
    end

    apply_suggestion

    next_suggestion = tunnel_query.find_or_create_next_step!(current_rule: @llm_rule_suggestion.rule)

    if next_suggestion
      LLM::ImproveProcedureJob.perform_now(@procedure, params[:tunnel_id], next_suggestion.rule, action: 'accept_simplification', user_id: current_administrateur.user.id)
      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: params[:tunnel_id], rule: next_suggestion.rule), notice: "Parfait, continuons"
    else
      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: params[:tunnel_id], rule: 'cleaner'), notice: "Toutes les suggestions ont été examinées"
    end
  end

  def new_simplify
    active_tunnel_id = LLM::TunnelQuery.find_active_tunnel_id_for(draft)
    first_rule = LLM::Rule::SEQUENCE.first

    if active_tunnel_id
      query = LLM::TunnelQuery.new(procedure_revision: draft, tunnel_id: active_tunnel_id)
      last_step = query.last_completed_step

      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: active_tunnel_id, rule: last_step&.rule || first_rule),
        notice: "Vous avez un parcours en cours, reprise là où vous étiez."
    else
      tunnel_id = generate_tunnel_id
      LLM::TunnelQuery.new(procedure_revision: draft, tunnel_id:).find_or_create_next_step!(current_rule: nil)
      redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id:, rule: first_rule)
    end
  end

  private

  def tunnel_query
    @tunnel_query ||= LLM::TunnelQuery.new(procedure_revision: draft, tunnel_id: params[:tunnel_id])
  end

  def apply_suggestion
    ActiveRecord::Base.transaction do
      if @llm_rule_suggestion.llm_rule_suggestion_items.empty?
        @llm_rule_suggestion.skipped!
      else
        @llm_rule_suggestion.assign_attributes(suggestion_items_attributes)
        @llm_rule_suggestion.save!
        @procedure.draft_revision.apply_llm_rule_suggestion_items(@llm_rule_suggestion.changes_to_apply)
        @llm_rule_suggestion.accepted!
      end
    end
  end

  def ensure_simpliscore_enabled
    return if @procedure.feature_enabled?(:llm_nightly_improve_procedure)

    redirect_to admin_procedure_path(@procedure), alert: "Les appels aux modèles de langage ne sont pas activés pour cette procédure."
  end

  def current_schema_hash
    # Don't memoize: schema can change during action (e.g., in accept_simplification)
    Digest::SHA256.hexdigest(draft.reload.schema_to_llm.to_json)
  end

  def suggestion_items_attributes
    params.require(:llm_rule_suggestion)
      .permit(llm_rule_suggestion_items_attributes: [:id, :verify_status])
  end

  def generate_tunnel_id
    loop do
      tunnel_id = SecureRandom.hex(3)
      return tunnel_id unless draft.llm_rule_suggestions.exists?(tunnel_id:)
    end
  end

  def ensure_valid_tunnel
    # SECURITY: Verify tunnel belongs to this procedure via draft.llm_rule_suggestions scope
    return if params[:tunnel_id].blank? # Legacy routes without tunnel_id
    return if draft.llm_rule_suggestions.exists?(tunnel_id: params[:tunnel_id])

    redirect_to new_simplify_admin_procedure_types_de_champ_path(@procedure),
      alert: "Ce parcours n'existe pas ou a expiré."
  end
end
