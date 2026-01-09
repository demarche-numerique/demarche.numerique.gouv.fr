# frozen_string_literal: true

module Instructeurs
  class ProceduresController < InstructeurController
    include InstructeurProcedureConcern
    include ProConnectSessionConcern

    before_action :ensure_ownership!, except: [:index, :counters, :synthese, :order_positions, :update_order_positions, :select_procedure]
    before_action :ensure_not_super_admin!, only: [:download_export, :exports]
    after_action :mark_latest_revision_as_seen, only: [:history]

    ITEMS_PER_PAGE = 100

    def index
      all_procedures = current_instructeur
        .procedures
        .kept

      all_procedures_for_listing = all_procedures
        .with_attached_logo

      dossiers = current_instructeur.dossiers
        .joins(groupe_instructeur: :procedure)
        .where(procedures: { hidden_at: nil })

      # .uniq is much more faster than a distinct on a joint column
      procedures_dossiers_en_cours = dossiers.joins(:revision).en_cours.pluck(ProcedureRevision.arel_table[:procedure_id]).uniq

      @all_procedures = all_procedures.order(closed_at: :desc, unpublished_at: :desc, published_at: :desc, created_at: :desc)
      publiees_or_closes_with_dossiers_en_cours = all_procedures_for_listing.publiees.or(all_procedures.closes.where(id: procedures_dossiers_en_cours))
      ensure_instructeur_procedures_for(publiees_or_closes_with_dossiers_en_cours)
      closes_with_no_dossier_en_cours = all_procedures.closes.excluding(all_procedures.closes.where(id: procedures_dossiers_en_cours))

      @procedures_en_cours_count = publiees_or_closes_with_dossiers_en_cours.count
      @procedures_draft_count = all_procedures_for_listing.brouillons.count
      @procedures_closes_count = closes_with_no_dossier_en_cours.count

      @statut = params[:statut].presence || 'en-cours'
      @procedures = collection_scope_for_statut(
        @statut,
        publiees_or_closes_with_dossiers_en_cours,
        all_procedures_for_listing.brouillons,
        closes_with_no_dossier_en_cours
      ).includes(:procedure_paths)

      if current_administrateur.present?
        @procedures = @procedures.includes(:administrateurs_procedures)
      end
    end

    def counters
      all_procedures = current_instructeur.procedures.kept
      procedures_dossiers_en_cours = current_instructeur.dossiers
        .joins(groupe_instructeur: :procedure)
        .where(procedures: { hidden_at: nil })
        .joins(:revision)
        .en_cours
        .pluck(ProcedureRevision.arel_table[:procedure_id])
        .uniq

      @statut = params[:statut].presence || 'en-cours'
      publiees_or_closes_with_dossiers_en_cours = all_procedures.publiees.or(all_procedures.closes.where(id: procedures_dossiers_en_cours))
      closes_with_no_dossier_en_cours = all_procedures.closes.excluding(all_procedures.closes.where(id: procedures_dossiers_en_cours))

      @procedures = collection_scope_for_statut(@statut,
                                                publiees_or_closes_with_dossiers_en_cours,
                                                all_procedures.brouillons,
                                                closes_with_no_dossier_en_cours)

      @counters = InstructeursProceduresCountersService.new(
        procedures: all_procedures,
        instructeur: current_instructeur
      ).call

      @procedure_ids_with_notifications = DossierNotification.notifications_sticker_for_instructeur_procedures(@counters.groupes_instructeurs_ids, current_instructeur)
      @notifications_counts_per_procedure = DossierNotification.notifications_counts_for_instructeur_procedures(@counters.groupes_instructeurs_ids, current_instructeur)
    end

    def synthese
      @counters = InstructeursProceduresCountersService.new(
        procedures: current_instructeur.procedures.kept,
        instructeur: current_instructeur
      ).call
    end

    def order_positions
      all_procedures = current_instructeur
        .procedures
        .kept

      dossiers = current_instructeur.dossiers
        .joins(groupe_instructeur: :procedure)
        .where(procedures: { hidden_at: nil })

      procedures_dossiers_en_cours = dossiers.joins(:revision).en_cours.pluck(ProcedureRevision.arel_table[:procedure_id]).uniq

      publiees_or_closes_with_dossiers_en_cours = all_procedures.publiees.or(all_procedures.closes.where(id: procedures_dossiers_en_cours))

      @procedures = publiees_or_closes_with_dossiers_en_cours.order_by_position_for(current_instructeur)

      render layout: "empty_layout"
    end

    def update_order_positions
      InstructeursProcedure.update_instructeur_procedures_positions(current_instructeur, ordered_procedure_ids_params)
      redirect_to instructeur_procedures_path, notice: "L'ordre des démarches a été mis à jour."
    end

    def select_procedure
      return redirect_to instructeur_procedure_path(procedure_id: params[:procedure_id]) if params[:procedure_id].present?

      redirect_to instructeur_procedures_path
    end

    def display_notifications
      if params[:display] == 'true'
        notifications = DossierNotification.notifications_for_instructeur_procedure(groupe_instructeur_ids, current_instructeur)
      end

      respond_to do |format|
        @procedure_id = procedure_id
        @notifications = notifications || {}
        @display = params[:display]
        format.turbo_stream
      end
    end

    def show
      @procedure = procedure
      # Technically, procedure_presentation already sets the attribute.
      # Setting it here to make clear that it is used by the view
      @procedure_presentation = procedure_presentation
      @instructeur_procedure = find_or_create_instructeur_procedure(procedure)

      @current_filters = procedure_presentation.filters_for(statut)
      @current_filters.each do |filter|
        if filter.column.groupe_instructeur?
          filter.column.options_for_select = current_instructeur.groupe_instructeur_options_for(procedure)
        end
      end
      @counts = current_instructeur
        .dossiers_count_summary(groupe_instructeur_ids)
        .symbolize_keys
      @can_download_dossiers = (@counts[:tous] + @counts[:archives]) > 0 && !instructeur_as_manager?

      dossiers = Dossier.where(groupe_instructeur_id: groupe_instructeur_ids)
      dossiers_count = @counts[statut.underscore.to_sym]

      @followed_dossiers_id = current_instructeur
        .followed_dossiers
        .en_cours
        .merge(dossiers.visible_by_administration)
        .pluck(:id)

      @last_export = last_export_for(statut)

      begin
        @filtered_sorted_ids = DossierFilterService.filtered_sorted_ids(dossiers, statut, procedure_presentation.filters_for(statut), procedure_presentation.sorted_column, current_instructeur, count: dossiers_count)

        @archived_dossiers_count = if statut == 'tous'
          all_filtered_sorted_ids = DossierFilterService.filtered_sorted_ids(dossiers, statut, procedure_presentation.filters_for(statut), procedure_presentation.sorted_column, current_instructeur, count: dossiers_count, include_archived: true)

          all_filtered_sorted_ids.size - @filtered_sorted_ids.size
        else
          0
        end
      rescue ActiveRecord::StatementInvalid => e
        raise e if !(e.message =~ /PG::UndefinedFunction/) # StatementInvalid is too generic, we'll add more cases if needed

        Sentry.capture_message(
          "Destroying invalid ProcedurePresentation",
          extra: {
            procedure_presentation_id: procedure_presentation.id,
            errors: e.message,
            filters: procedure_presentation.filters_for(statut).map(&:to_json).join,
          }
        )

        procedure_presentation.destroy_filters_for!(statut)

        return redirect_to [:instructeur, @procedure, statut:], alert: t('.reinit_display')
      end

      page = params[:page].presence || 1

      @dossiers_count = @filtered_sorted_ids.size

      @filtered_sorted_paginated_ids = Kaminari
        .paginate_array(@filtered_sorted_ids)
        .page(page)
        .per(ITEMS_PER_PAGE)

      @projected_dossiers = DossierProjectionService.project(@filtered_sorted_paginated_ids, procedure_presentation.displayed_columns)
      @disable_checkbox_all = @projected_dossiers.all? { _1.batch_operation_id.present? }

      @batch_operations = BatchOperation.joins(:groupe_instructeurs)
        .where(groupe_instructeurs: current_instructeur.groupe_instructeurs.where(procedure_id: @procedure.id))
        .where(seen_at: nil)
        .distinct

      @statut_with_notifications = DossierNotification.notifications_sticker_for_instructeur_procedure(groupe_instructeur_ids, current_instructeur)
      @notifications = DossierNotification.notifications_for_instructeur_dossiers(current_instructeur, @filtered_sorted_paginated_ids)
      @has_export_notification = notify_exports?
      @has_unseen_revision_notification = notify_unseen_revisions?(@instructeur_procedure)

      cache_show_procedure_state # don't move in callback, inherited by Instructeurs::DossiersController
    end

    def deleted_dossiers
      @procedure = procedure
      @deleted_dossiers = @procedure
        .deleted_dossiers
        .order(:dossier_id)
        .page params[:page]

      @a_suivre_count, @suivis_count, @traites_count, @tous_count, @archives_count, @supprimes_count, @expirant_count = current_instructeur
        .dossiers_count_summary(groupe_instructeur_ids)
        .fetch_values('a_suivre', 'suivis', 'traites', 'tous', 'archives', 'supprimes', 'expirant')
      @can_download_dossiers = (@tous_count + @archives_count) > 0 && !instructeur_as_manager?

      @statut = 'supprime'
    end

    def download_export
      groupe_instructeurs = current_instructeur
        .groupe_instructeurs
        .where(procedure: procedure)

      export = Export.find_or_create_fresh_export(export_format, groupe_instructeurs, current_instructeur, **export_options)

      @procedure = procedure
      @statut = export_options[:statut]
      @dossiers_count = export.count

      @last_export = last_export_for(@statut)

      if export.available?
        respond_to do |format|
          format.turbo_stream do
            flash.notice = t('instructeurs.procedures.export_available_html', file_format: export.format, file_url: export.file.url)
          end

          format.html do
            redirect_to url_from(export.file.url)
          end
        end
      else
        respond_to do |format|
          format.turbo_stream do
            if !params[:no_progress_notification]
              flash.notice = t('instructeurs.procedures.export_pending_html', url: exports_instructeur_procedure_path(procedure))
            end
          end
          format.html do
            redirect_to exports_instructeur_procedure_path(procedure), notice: t('instructeurs.procedures.export_pending_html', url: exports_instructeur_procedure_path(procedure))
          end
        end
      end
    end

    def polling_last_export
      @statut = statut
      @last_export = last_export_for(@statut)
      if @last_export.available?
        flash.notice = t('instructeurs.procedures.export_available_html', file_format: @last_export.format, file_url: @last_export.file.url)
      else
        flash.notice = t('instructeurs.procedures.export_pending_html', url: exports_instructeur_procedure_path(procedure))
      end
    end

    def polling_batch_operation
      render turbo_stream: turbo_stream.refresh
    end

    def notification_preferences
      @procedure = procedure
      @instructeur_procedure = find_or_create_instructeur_procedure(@procedure)
    end

    def update_email_notifications
      instructeur_procedure = InstructeursProcedure.find_by!(procedure_id:, instructeur: current_instructeur)
      instructeur_procedure.update!(email_notification_params)

      flash.notice = t('instructeurs.procedures.email_preferences.flash_notice')
      redirect_to instructeur_procedure_path(procedure)
    end

    def update_badge_notifications
      instructeur_procedure = InstructeursProcedure.find_by!(procedure_id:, instructeur: current_instructeur)

      old_preferences = instructeur_procedure.notification_preferences
      instructeur_procedure.update!(badge_notification_params)
      new_preferences = instructeur_procedure.notification_preferences

      instructeur_procedure.refresh_notifications(groupe_instructeur_ids, old_preferences, new_preferences)

      flash.notice = t('instructeurs.procedures.badge_preferences.flash_notice')
      redirect_to instructeur_procedure_path(procedure)
    end

    def stats
      @procedure = procedure
      @usual_traitement_time = @procedure.stats_usual_traitement_time
      @dossiers_funnel = @procedure.stats_dossiers_funnel
      @termines_states = @procedure.stats_termines_states
      @termines_by_week = @procedure.stats_termines_by_week
      @usual_traitement_time_by_month = @procedure.stats_usual_traitement_time_by_month_in_days
    end

    def exports
      @procedure = procedure
      @exports = Export.for_groupe_instructeurs(groupe_instructeur_ids).ante_chronological
      cookies.encrypted[cookies_export_key] = {
        value: DateTime.current,
        expires: Export::MAX_DUREE_GENERATION + Export::MAX_DUREE_CONSERVATION_EXPORT,
        httponly: true,
        secure: Rails.env.production?,
      }

      respond_to do |format|
        format.turbo_stream
        format.html
      end
    end

    def export_templates
      @procedure = procedure
      @export_templates = current_instructeur.export_templates_for(procedure)
    end

    def email_usagers
      @procedure = procedure
      @bulk_messages = BulkMessage.where(procedure: procedure)
      @dossiers_count_per_groupe_instructeur = procedure.dossiers.state_brouillon.visible_by_user.group(:groupe_instructeur_id).count
    end

    def create_multiple_commentaire_for_brouillons
      @procedure = procedure
      errors = []
      bulk_message = current_instructeur.bulk_messages.build(bulk_message_params)

      dossiers = reachable_brouillons

      dossiers.each do |dossier|
        commentaire = CommentaireService.create(current_instructeur, dossier, bulk_message_params.except(:targets))
        if commentaire.errors.empty?
          commentaire.dossier.touch(:last_commentaire_updated_at)
        else
          errors << dossier.id
        end
      end

      valid_dossiers_count = dossiers.count - errors.count
      bulk_message.assign_attributes(
        dossier_count: valid_dossiers_count,
        dossier_state: Dossier.states.fetch(:brouillon),
        sent_at: Time.zone.now,
        instructeur_id: current_instructeur.id,
        procedure_id: @procedure.id
      )
      bulk_message.save!

      if errors.empty?
        flash[:notice] = "Tous les messages ont été envoyés avec succès"
      else
        flash[:alert] = "Envoi terminé. Cependant #{errors.count} messages n'ont pas été envoyés"
      end
      redirect_to instructeur_procedure_path(@procedure)
    end

    def administrateurs
      @procedure = procedure
      @administrateurs = procedure.administrateurs
    end

    def apercu
      @procedure = procedure
      @preview_service = DossierPreviewService.new(procedure:, current_user:)
      @dossier = @preview_service.dossier
    end

    def history
      @procedure = procedure
      @revisions = @procedure.revisions
        .includes(administrateur: :user)
        .where.not(published_at: nil)
        .reorder(published_at: :desc)
      @instructeur_procedure = find_or_create_instructeur_procedure(@procedure)
    end

    private

    def mark_latest_revision_as_seen
      return if @procedure.published_revision_id.blank?
      @instructeur_procedure.update(last_revision_seen_id: @procedure.published_revision_id)
    end

    def groupe_instructeur_ids_params
      bulk_message_params = params.require(:bulk_message).permit(:without_group, groupe_instructeur_ids: {}).to_h
      bulk_message_params
        .fetch(:groupe_instructeur_ids) { [] }
        .filter_map { |id, selected| selected == "true" ? id : nil }
        .concat(bulk_message_params.dig(:without_group).eql?('1') ? [nil] : [])
    end

    def reachable_brouillons
      if procedure.routing_enabled?
        procedure.dossiers.state_brouillon.visible_by_user.where(groupe_instructeur_id: groupe_instructeur_ids_params)
      else
        procedure.dossiers.state_brouillon.visible_by_user
      end
    end

    def email_notification_params
      params.require(:instructeurs_procedure).permit(
        :instant_email_new_dossier,
        :instant_email_new_message,
        :instant_email_new_expert_avis,
        :instant_email_dossier_expiration,
        :instant_email_dossier_expired,
        :instant_email_dossier_deletion,
        :daily_email_summary,
        :weekly_email_summary
      )
    end

    def assign_tos
      @assign_tos ||= current_instructeur
        .assign_to
        .joins(:groupe_instructeur)
        .where(groupe_instructeur: { procedure_id: procedure_id })
    end

    def groupe_instructeur_ids
      @groupe_instructeur_ids ||= assign_tos
        .map(&:groupe_instructeur_id)
    end

    def statut
      @statut ||= (params[:statut].presence || 'a-suivre')
    end

    def export_format
      @export_format ||= params[:export_format].presence || export_template&.kind
    end

    def export_template
      @export_template ||= ExportTemplate.find(params[:export_template_id]) if params[:export_template_id].present?
    end

    def export_options
      @export_options ||= {
        time_span_type: params[:time_span_type],
        statut: params[:statut],
        export_template:,
        include_archived: params[:include_archived],
        procedure_presentation: params[:statut].present? ? procedure_presentation : nil,
      }.compact
    end

    def procedure_id
      params[:procedure_id]
    end

    def procedure
      Procedure
        .with_attached_logo
        .with_active_revision
        .find(procedure_id)
        .tap { Sentry.set_tags(procedure: _1.id) }
    end

    def ensure_ownership!
      if !current_instructeur.procedures.include?(procedure)
        flash[:alert] = "Vous n’avez pas accès à cette démarche"
        return redirect_to root_path
      end

      ensure_pro_connect_if_required!
    end

    def ensure_pro_connect_if_required!
      return if procedure.pro_connect_restriction_none?
      return if logged_in_with_pro_connect?

      flash[:alert] = "Vous devez vous connecter par ProConnect pour accéder à cette démarche"
      redirect_to pro_connect_path
    end

    def redirect_to_avis_if_needed
      if current_instructeur.procedures.count == 0 && current_instructeur.avis.count > 0
        redirect_to instructeur_all_avis_path
      end
    end

    def procedure_presentation
      @procedure_presentation ||= begin
        procedure_presentation, errors = current_instructeur.procedure_presentation_and_errors_for_procedure_id(procedure_id)

        if errors.present?
          msg = "Votre affichage a dû être réinitialisé en raison du problème suivant : " + errors.full_messages.join(', ')
          if request.get?
            flash.now[:alert] = msg
          else
            flash[:alert] = msg
          end
        end

        procedure_presentation
      end
    end

    def bulk_message_params
      params.require(:bulk_message).permit(:body)
    end

    def notify_exports?
      last_seen_at = begin
                       DateTime.parse(cookies.encrypted[cookies_export_key])
                     rescue
                       nil
                     end

      scope = Export.generated.for_groupe_instructeurs(groupe_instructeur_ids)
      scope = scope.where(updated_at: last_seen_at...) if last_seen_at

      scope.exists?
    end

    def notify_unseen_revisions?(instructeur_procedure)
      return false if procedure.published_revision_id.blank?

      return false if instructeur_procedure.last_revision_seen_id.blank?

      instructeur_procedure.last_revision_seen_id < procedure.published_revision_id
    end

    def last_export_for(statut)
      Export.where(user_profile: current_instructeur, statut: statut, updated_at: 1.hour.ago..).last
    end

    def cookies_export_key
      "exports_#{@procedure.id}_seen_at"
    end

    def ordered_procedure_ids_params
      params.require(:ordered_procedure_ids)
    end

    def cache_show_procedure_state
      cache = Cache::ProcedureDossierPagination.new(procedure_presentation:, statut:)

      cache.save_context(ids: @filtered_sorted_paginated_ids, incoming_page: params[:page])
    end

    def collection_scope_for_statut(statut, publiees_or_closes_with_dossiers_en_cours, procedures_draft, closes_with_no_dossier_en_cours)
      scope = case statut
      when 'en-cours'
        publiees_or_closes_with_dossiers_en_cours.order_by_position_for(current_instructeur)
      when 'brouillons'
        procedures_draft.order(created_at: :desc)
      when 'archivees'
        closes_with_no_dossier_en_cours.order(created_at: :desc)
      end

      scope
        .page(params[:page])
        .per(ITEMS_PER_PAGE)
        .strict_loading!
    end

    def badge_notification_params
      params.require(:instructeurs_procedure).permit(
        :display_dossier_depose_notifications,
        :display_dossier_modifie_notifications,
        :display_message_notifications,
        :display_annotation_instructeur_notifications,
        :display_avis_externe_notifications,
        :display_attente_correction_notifications,
        :display_attente_avis_notifications,
        :display_attente_reponse_notifications
      )
    end
  end
end
