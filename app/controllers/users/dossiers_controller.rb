# frozen_string_literal: true

module Users
  class DossiersController < UserController
    include DossierHelper
    include TurboChampsConcern
    include LockableConcern
    include ProConnectSessionConcern
    include Dry::Monads[:result]
    include DossierEditConcern

    layout 'procedure_context', only: [:identite, :update_identite, :siret, :update_siret]

    ACTIONS_ALLOWED_TO_ANY_USER = [:index, :new, :deleted_dossiers, :trash, :transfer_requests, :personnalisation, :update_personnalisation]
    ACTIONS_ALLOWED_TO_OWNER_OR_INVITE = [:show, :destroy, :demande, :messagerie, :brouillon, :modifier, :update, :create_commentaire, :attestation_depot, :restore, :champ, :check_completude, :notify_owner_for_changes, :revert_prefill]
    TRASH_ACTIONS = [:show_in_trash, :show_deleted]
    ITEMS_PER_PAGE = 25
    SIMPLE_LIST_THRESHOLD = 5

    helper_method :filter_params_slice

    before_action :ensure_ownership!, except: ACTIONS_ALLOWED_TO_ANY_USER + ACTIONS_ALLOWED_TO_OWNER_OR_INVITE + TRASH_ACTIONS
    before_action :redirect_if_hidden_or_deleted_dossier, only: [:show]
    before_action :ensure_ownership_or_invitation!, only: ACTIONS_ALLOWED_TO_OWNER_OR_INVITE
    before_action :ensure_dossier_can_be_updated, only: [:update_identite, :update_siret, :brouillon, :submit_brouillon, :submit_en_construction, :modifier, :update, :champ, :revert_prefill]
    before_action :ensure_dossier_can_be_filled, only: [:brouillon, :modifier, :submit_brouillon, :submit_en_construction, :update]
    before_action :ensure_dossier_can_be_viewed, only: [:show]
    before_action :ensure_pro_connect_for_procedure, only: [:brouillon, :modifier, :submit_brouillon, :submit_en_construction, :update]
    before_action :ensure_editing_brouillon, only: [:brouillon]
    before_action :forbid_closed_submission!, only: [:submit_brouillon]
    before_action :ensure_dossier_has_changes, only: [:submit_en_construction], if: :update_with_stream?
    before_action :set_dossier_stream, only: [:modifier, :update, :submit_en_construction, :check_completude, :champ, :revert_prefill], if: :update_with_stream?
    before_action :show_demarche_en_test_banner
    before_action :store_user_location!, only: :new
    before_action :set_default_value_for_france_connect_champs, only: [:brouillon, :modifier]
    before_action :prefill_champs_from_france_connect, only: [:brouillon, :modifier]

    around_action only: :submit_en_construction do |_controller, action|
      lock_action("lock-submit-en-construction-#{@dossier.id}", &action)
    end

    def index
      @filter = Users::DossierFilterService.new(user: current_user, params: params)
      @filter_panel_request = params[:filter_panel].present?

      if @filter_panel_request
        @procedures_for_select = procedures_for_select
        return
      end

      @dossiers = @filter.dossiers.page(page).per(ITEMS_PER_PAGE)
      @total_count = @dossiers.total_count
      @show_personnalisation_link = personnalisation_available?
      list_title = @filter.model_alerts.any? ? "filters.alerts" : "filters.no_alert"
      Skylight.instrument(title: list_title) do
        @dossiers.load
      end
      load_personnalisation_data(@dossiers)
      load_user_buffer_changes_data(@dossiers)
      @corbeille_count = current_user.dossiers.hidden_by_user.or(current_user.dossiers.hidden_by_expired).count
      @pending_transfers_count = current_user.dossier_transfers_received_pending.count
      @show_simple_list = params[:search].blank? && !@filter.active? && @total_count <= SIMPLE_LIST_THRESHOLD
      @procedures_for_select = @show_simple_list ? [] : procedures_for_select
    end

    def show
      pj_service = PiecesJustificativesService.new(user_profile: current_user, export_template: nil)
      respond_to do |format|
        format.pdf do
          @dossier = dossier_with_champs(pj_template: false)
          @acls = pj_service.acl_for_dossier_export(@dossier.procedure)
          render(template: 'dossiers/show', formats: [:pdf])
        end
        format.all do
          @dossier = dossier_with_champs
        end
      end
    end

    def demande
      @dossier = dossier_with_champs(pj_template: false)
    end

    def messagerie
      @dossier = dossier
      @commentaire = Commentaire.new
      Commentaire.mark_agent_messages_as_seen(@dossier)
    end

    def rendez_vous
      @dossier = dossier
      @rdv = @dossier.last_booked_rdv
    end

    def attestation
      if dossier.attestation&.pdf&.attached?
        redirect_to dossier.attestation.pdf.url, allow_other_host: true
      else
        flash.notice = t('.not_available')
        redirect_to dossier_path(dossier)
      end
    end

    def show_in_trash
      @hidden_dossier = hidden_dossier_for(params[:id])
      raise ActiveRecord::RecordNotFound if @hidden_dossier.nil?
    end

    def show_deleted
      @deleted_dossier = deleted_dossier_for(params[:id])
      raise ActiveRecord::RecordNotFound if @deleted_dossier.nil?
    end

    def attestation_depot
      raise ActionController::BadRequest if dossier.brouillon?
      @dossier = dossier
      pdf = @dossier.generate_or_reuse_attestation_depot
      send_data pdf,
        filename: t('users.dossiers.show.attestation_depot.filename', dossier_id: @dossier.id),
        type: 'application/pdf',
        disposition: 'attachment'
    end

    def set_accuse_lecture_agreement_at
      @dossier = dossier
      @dossier.update!(accuse_lecture_agreement_at: Time.zone.now)
      flash.notice = 'Accusé de lecture accepté'
      redirect_back_or_to(demande_dossier_path(@dossier))
    end

    def identite
      @dossier = dossier
      @user = current_user
      @no_description = true

      respond_to do |format|
        format.html do
          @dossier.prefill_individual_from_france_connect if @dossier.identity_from_fc? && !@dossier.for_tiers?
        end
        format.turbo_stream do
          @dossier.assign_for_tiers(params.dig(:dossier, :for_tiers) == 'true')

          # Persist the persona choice so the identity form survives a page reload:
          # `identity_updated_at` is what makes the form visible on the next GET.
          @dossier.update_columns(for_tiers: @dossier.for_tiers, identity_updated_at: Time.zone.now)
        end
      end
    end

    def update_identite
      @dossier = dossier
      @no_description = true

      @dossier.assign_for_tiers(dossier_params[:for_tiers] == 'true')

      sanitized_params = dossier_params.dup
      if mandataire_identity_locked?(@dossier)
        sanitized_params = sanitized_params.except(:mandataire_first_name, :mandataire_last_name)
      elsif identity_locked?(@dossier)
        # keep only birthdate for legacy procedures
        sanitized_params[:individual_attributes] = sanitized_params[:individual_attributes]&.except(:nom, :prenom, :gender)
        sanitized_params.delete(:individual_attributes) if sanitized_params[:individual_attributes].blank? # évite {} qui réinitialise l'individual
      end

      if @dossier.update(sanitized_params) && @dossier.individual.valid?
        if @dossier.for_tiers?
          email = sanitized_params.dig(:individual_attributes, :email)
          User.create_or_promote_to_tiers(email, SecureRandom.hex, @dossier) if email.present?
          @dossier.reset_champs_from_france_connect(updated_by: current_user.email)
        else
          @dossier.prefill_champs_from_france_connect(updated_by: current_user.email)
        end

        @dossier.update!(autorisation_donnees: true, identity_updated_at: Time.zone.now)

        flash.notice = t('.identity_saved')

        if dossier.en_construction?
          DossierNotification.create_notification(dossier, :dossier_modifie)
          redirect_to demande_dossier_path(@dossier)
        else
          redirect_to brouillon_dossier_path(@dossier)
        end
      else
        flash.now.alert = @dossier.individual.errors.full_messages + @dossier.errors.full_messages
        render :identite
      end
    end

    def siret
      @dossier = dossier
      @no_description = true
    end

    def update_siret
      @dossier = dossier
      @no_description = true

      # We use the user as the holder model object for the siret value
      # (so that we can restore it on the form in case of error).
      #
      # This is the only remaining use of User#siret: it could be refactored away.
      # However some existing users have a siret but no associated etablissement,
      # so we would need to analyze the legacy data and decide what to do with it.

      siret_model = Siret.new(siret: siret_params[:siret])
      valid = siret_model.valid?
      current_user.siret = sanitized_siret = siret_model.siret
      if !valid
        return render_siret_error(siret_model.errors.full_messages)
      end

      case APIEntrepriseService.create_etablissement_with_fallback(@dossier, sanitized_siret, current_user.id)
      in Success
        current_user.update!(siret: sanitized_siret)
        @dossier.update!(autorisation_donnees: true, last_champ_updated_at: Time.zone.now)
        redirect_to etablissement_dossier_path
      in Failure(type: (:not_found | :unavailable_for_legal_reasons) => type, **)
        render_siret_error(t("errors.messages.siret.#{type}"))
      in Failure => failure
        APIEntrepriseService.report_error(failure.failure, dossier_id: @dossier.id, siret: sanitized_siret)
        render_siret_error(t('errors.messages.siret.network_error'))
      end
    end

    def etablissement
      @dossier = dossier

      # Redirect if the user attempts to access the page URL directly
      if !@dossier.etablissement
        flash.alert = t('.no_establishment')
        return redirect_to siret_dossier_path(@dossier)
      end
    end

    def brouillon
      session.delete(:prefill_token)
      session.delete(:prefill_params)
      @dossier = dossier_with_champs
      @dossier.validate(:champs_public_value)
    end

    def submit_brouillon
      @dossier = dossier_with_champs(pj_template: false)
      dossier.champs_public_valid?

      if @dossier.errors.blank? && @dossier.can_passer_en_construction?
        begin
          @dossier.submitted_with_france_connect = current_user.loged_in_with_france_connect.present?
          @dossier.submitted_with_pro_connect = logged_in_with_pro_connect?
          @dossier.passer_en_construction!
          redirect_to merci_dossier_path(@dossier)
          return
        rescue ActiveRecord::RecordInvalid
          Sentry.capture_message(
            "422: Dossier failed to pass en construction",
            extra: {
              errors: @dossier.errors.full_messages,
            }
          )
          # Continue to render brouillon below
        end
      end

      render :brouillon
    end

    def extend_conservation
      dossier.extend_conservation(dossier.procedure.duree_conservation_dossiers_dans_ds.months)
      flash[:notice] = t('views.users.dossiers.archived_dossier', duree_conservation_dossiers_dans_ds: dossier.procedure.duree_conservation_dossiers_dans_ds)
      redirect_back_or_to(dossier_path(@dossier))
    end

    def extend_conservation_and_restore
      dossier.extend_conservation_and_restore(dossier.procedure.duree_conservation_dossiers_dans_ds.months, current_user)
      flash[:notice] = t('views.users.dossiers.archived_dossier', duree_conservation_dossiers_dans_ds: dossier.procedure.duree_conservation_dossiers_dans_ds)
      redirect_back_or_to(dossier_path(@dossier))
    end

    def modifier
      @dossier = dossier_with_champs
    end

    def submit_en_construction
      dossier.with_champs

      if cast_bool(params.dig(:dossier, :pending_correction))
        dossier.resolve_pending_correction
      end

      dossier.champs_public_valid?

      if dossier.errors.blank? && dossier.can_passer_en_construction?
        dossier.submitted_with_france_connect = current_user.loged_in_with_france_connect.present?
        dossier.submitted_with_pro_connect = logged_in_with_pro_connect?
        dossier.usager_submit_en_construction!

        redirect_to dossier_path(dossier)
      else
        render :modifier
      end
    end

    def check_completude
      @dossier = dossier_with_champs
      dossier.champs_public_valid?

      if @dossier.errors.blank? && @dossier.can_passer_en_construction?
        flash.notice = t('.success')
        if dossier.brouillon?
          redirect_to brouillon_dossier_path(@dossier)
        else
          redirect_to modifier_dossier_path(@dossier)
        end
      else
        flash.alert = t('.error')
        if dossier.brouillon?
          render :brouillon
        else
          render :modifier
        end
      end
    end

    def notify_owner_for_changes
      dossier = dossier_with_champs
      DossierMailer.notify_owner_for_changes(dossier, current_user).deliver_later(wait: 30.minutes)
      flash.notice = t('.success')

      if dossier.brouillon?
        redirect_to brouillon_dossier_path(dossier)
      else
        redirect_to modifier_dossier_path(dossier)
      end
    end

    def update
      @dossier = dossier_with_champs(pj_template: false)
      update_champ_and_compute_errors(scope: :public)

      respond_to do |format|
        format.turbo_stream do
          @to_show, @to_hide, @to_update = champs_to_turbo_update(champs_attributes_params(:public), dossier.flat_champs_public)
          render :update, layout: false
        end
      end
    end

    def merci
      @dossier = current_user.dossiers.includes(:procedure).find(params[:id])
    end

    # polling url for champ
    def champ
      @polling = true
      @dossier = dossier_with_champs(pj_template: false)
      type_de_champ = dossier.find_type_de_champ_by_stable_id(params[:stable_id], :public)
      champ = dossier.project_champ(type_de_champ, row_id: params[:row_id])

      champ.validate(:champ_value) if champ.done?
      respond_to do |format|
        format.turbo_stream do
          @to_show, @to_hide, @to_update = champ_to_turbo_update(champ, dossier.flat_champs_public)

          render :update, layout: false
        end
      end
    end

    def revert_prefill
      @dossier = dossier_with_champs(pj_template: false)
      champ = @dossier.public_champ_for_update(params[:stable_id], updated_by: current_user.email)

      champ.revert_to_prefilled_value! if champ.prefilled_original_value.present?

      respond_to do |format|
        format.turbo_stream do
          @to_show, @to_hide = []
          @to_update = [champ]
          render :update, layout: false
        end
      end
    end

    def create_commentaire
      @commentaire = CommentaireService.create(current_user, dossier, commentaire_params)

      if @commentaire.errors.empty?
        timestamps = [:last_commentaire_updated_at, :updated_at]
        timestamps << :last_commentaire_piece_jointe_updated_at if @commentaire.piece_jointe.attached?

        @commentaire.dossier.touch(*timestamps)

        DossierNotification.create_notification(dossier, :message)

        dossier.resolve_pending_response!

        flash.notice = t('.message_send')

        respond_to do |format|
          format.turbo_stream do
            @dossier = dossier
            @connected_user = current_user
            @form_url = commentaire_dossier_path(dossier)
            render template: 'shared/dossiers/create_commentaire'
          end
          format.html { redirect_to messagerie_dossier_path(dossier) }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            @dossier = dossier
            @connected_user = current_user
            @form_url = commentaire_dossier_path(dossier)
            render template: 'shared/dossiers/create_commentaire', status: :unprocessable_content
          end
          format.html do
            flash.now.alert = @commentaire.errors.full_messages
            render :messagerie, status: :unprocessable_content
          end
        end
      end
    end

    def destroy
      if dossier.can_be_deleted_by_user?
        if current_user.owns?(dossier)
          dossier.hide_and_keep_track!(current_user, :user_request)
        elsif current_user.invite?(dossier)
          current_user.invites.where(dossier:).destroy_all
        end
        flash.notice = t('users.dossiers.ask_deletion.soft_deleted_dossier')
        redirect_to dossiers_path
      else
        flash.alert = t('users.dossiers.ask_deletion.undergoingreview')
        redirect_to dossiers_path
      end
    end

    def new
      erase_user_location!

      begin
        procedure = if params[:brouillon]
          Procedure.publiees.or(Procedure.brouillons).with_active_revision.find(params[:procedure_id])
        else
          Procedure.publiees.with_active_revision.find(params[:procedure_id])
        end
      rescue ActiveRecord::RecordNotFound
        flash.alert = t('errors.messages.procedure_not_found')
        return redirect_to dossiers_path
      end

      return if ensure_pro_connect_for_procedure(procedure)

      dossier = Dossier.new(
        revision: params[:brouillon] ? procedure.draft_revision : procedure.active_revision,
        user: current_user,
        state: Dossier.states.fetch(:brouillon)
      )
      dossier.build_default_values
      dossier.save!
      DossierMailer.with(dossier:).notify_new_draft.deliver_later(wait: 1.hour)
      Ami::CreateNotificationService.call(dossier:)

      if dossier.procedure.for_individual
        redirect_to identite_dossier_path(dossier)
      else
        redirect_to siret_dossier_path(id: dossier.id)
      end
    end

    def dossier_for_help
      return @dossier if @dossier

      dossier_id = params[:id] || params[:dossier_id]
      return nil if dossier_id.blank?

      id = dossier_id.to_i
      current_user.dossiers.visible_by_user.find_by(id:) ||
        current_user.dossiers_invites.visible_by_user.find_by(id:)
    end

    def transferer
      @transfer = DossierTransfer.new(dossiers: [dossier])
    end

    def restore
      dossier.restore(current_user)
      flash.notice = t('users.dossiers.restore')
      redirect_to dossiers_path
    end

    def clone
      cloned_dossier = @dossier.clone
      DossierMailer.with(dossier: cloned_dossier).notify_new_draft.deliver_later
      Ami::CreateNotificationService.call(dossier: cloned_dossier)
      flash.notice = t('users.dossiers.cloned_success')
      redirect_to brouillon_dossier_path(cloned_dossier)
    rescue ActiveRecord::RecordInvalid => e
      flash.alert = e.record.errors.full_messages
      redirect_to dossier_path(@dossier)
    end

    def deleted_dossiers
      @deleted_dossiers = current_user.deleted_dossiers.includes(:procedure).order_by_updated_at.page(page)
    end

    def transfer_requests
      @pending_transfers = current_user.dossier_transfers_received_pending
      render layout: 'empty_layout'
    end

    def personnalisation
      return redirect_to dossiers_path if !personnalisation_available?

      @personnalisable_procedures = personnalisable_procedures
      @personnalisations_by_procedure_id = current_user
        .dossiers_list_personnalisations
        .where(procedure_id: @personnalisable_procedures.map(&:id))
        .index_by(&:procedure_id)
      render layout: 'empty_layout'
    end

    def update_personnalisation
      return redirect_to dossiers_path if !personnalisation_available?

      personnalisations = personnalisation_params
      procedures_by_id = user_procedures.where(id: personnalisations.keys).index_by { _1.id.to_s }
      results = personnalisations.map do |procedure_id, attrs|
        procedure = procedures_by_id[procedure_id.to_s]
        next true if procedure.nil?

        submitted_ids = Array(attrs[:displayed_columns]).compact_blank
        columns =
          if submitted_ids.empty?
            []
          else
            columns_by_id = procedure.customizable_columns.index_by(&:id)
            submitted_ids.filter_map { columns_by_id[_1] }
          end
        perso = current_user.dossiers_list_personnalisations.find_or_initialize_by(procedure_id:)
        perso.update(displayed_columns: columns)
      end

      if results.all?
        redirect_to dossiers_path, notice: t('views.users.dossiers.personnalisation.saved')
      else
        redirect_to dossiers_path, alert: t('views.users.dossiers.personnalisation.error')
      end
    end

    def trash
      @statut = 'dossiers-supprimes'
      @dossiers = current_user.dossiers
        .hidden_by_user
        .or(current_user.dossiers.hidden_by_expired)
        .includes(*Users::DossierFilterService::USER_LIST_PRELOADS)
        .order(updated_at: :desc)
        .page(page)
        .per(ITEMS_PER_PAGE)
      @total_count = @dossiers.total_count
      load_user_buffer_changes_data(@dossiers)
    end

    private

    def identity_locked?(dossier)
      dossier.identity_from_fc?
    end

    def mandataire_identity_locked?(dossier)
      dossier.for_tiers? && dossier.identity_from_fc?
    end

    def filter_params_slice
      params.permit(*Users::DossierFilterService::ALLOWED_PARAMS)
    end

    def procedures_for_select
      revision_ids = ProcedureRevision
        .where(id: current_user.dossiers.visible_by_user.select(:revision_id))
        .or(ProcedureRevision.where(id: current_user.dossiers_invites.visible_by_user.select(:revision_id)))
        .select(:procedure_id)
      Procedure.where(id: revision_ids).distinct.order(:libelle).pluck(:libelle, :id)
    end

    def store_user_location!
      store_location_for(:user, request.fullpath)
    end

    def erase_user_location!
      clear_stored_location_for(:user)
    end

    def show_demarche_en_test_banner
      if @dossier.present? && @dossier.revision.draft?
        flash.now.alert = t('users.dossiers.test_procedure')
      end
    end

    def ensure_dossier_can_be_updated
      if !dossier.can_be_updated_by_user?
        flash.alert = t('users.dossiers.no_longer_editable')
        redirect_to dossier_path(dossier)
      end
    end

    def ensure_dossier_can_be_filled
      if !dossier.autorisation_donnees
        if dossier.procedure.for_individual
          flash.alert = t('users.dossiers.fill_identity.individual')
          redirect_to identite_dossier_path(dossier)
        else
          flash.alert = t('users.dossiers.fill_identity.siret')
          redirect_to siret_dossier_path(dossier)
        end
      end
    end

    def ensure_dossier_can_be_viewed
      if dossier.brouillon?
        redirect_to brouillon_dossier_path(dossier)
      end
    end

    def ensure_editing_brouillon
      if !dossier.brouillon?
        redirect_to modifier_dossier_path(@dossier)
      end
    end

    def ensure_pro_connect_for_procedure(procedure = dossier.procedure)
      return if procedure.blank?
      return if !procedure.pro_connect_restriction_all?
      return if logged_in_with_pro_connect?

      store_location_for(:user, request.fullpath)
      flash.alert = t('users.dossiers.pro_connect_restriction_required')
      redirect_to pro_connect_required_path
    end

    def page
      [params[:page].to_i, 1].max
    end

    def dossier_scope
      if action_name == 'update' || action_name == 'champ'
        Dossier.visible_by_user.or(Dossier.for_procedure_preview)
      elsif action_name == 'restore'
        Dossier.hidden_by_user.or(Dossier.hidden_by_not_modified_for_a_long_time)
      elsif action_name == 'extend_conservation_and_restore' ||
            (action_name == 'show' && request.format.pdf?) ||
            action_name == 'attestation'
        Dossier.visible_by_user.or(Dossier.hidden_by_expired)
      else
        Dossier.visible_by_user
      end
    end

    def dossier
      @dossier ||= dossier_scope.find(params[:id] || params[:dossier_id]).tap do
        set_sentry_dossier(_1)
      end
    end

    def dossier_with_champs(pj_template: true)
      DossierPreloader.load_one(dossier, pj_template:)
    end

    def ensure_dossier_has_changes
      return if dossier.with_champs.user_buffer_changes?

      flash[:alert] = t('users.dossiers.en_construction_submitted')
      redirect_to dossier_path(dossier)
    end

    def set_dossier_stream
      dossier.with_update_stream(current_user)
    end

    def update_with_stream?
      dossier.en_construction?
    end

    def ensure_ownership!
      if !current_user.owns?(dossier)
        forbidden!
      end
    end

    def ensure_ownership_or_invitation!
      if !current_user.owns_or_invite?(dossier)
        forbidden!
      end
    end

    def forbid_closed_submission!
      if !dossier.can_transition_to_en_construction?
        forbidden!
      end
    end

    def forbidden!
      flash[:alert] = t('users.dossiers.no_access_html', email: current_user.email)
      redirect_to root_path
    end

    def render_siret_error(error_message)
      flash.alert = error_message
      render :siret
    end

    def dossier_params
      params.require(:dossier).permit(:for_tiers, :mandataire_first_name, :mandataire_last_name, individual_attributes: [:gender, :nom, :prenom, :birthdate, :email, :notification_method])
    end

    def siret_params
      params.require(:user).permit(:siret)
    end

    def commentaire_params
      params.require(:commentaire).permit(:body, piece_jointe: [])
    end

    def load_personnalisation_data(dossiers)
      @personnalisations_by_procedure_id = {}
      @champs_by_dossier_id = {}
      return if !feature_enabled?(:dossiers_list_personnalisation)

      @personnalisations_by_procedure_id = current_user.dossiers_list_personnalisations
        .where(procedure_id: dossiers.map { _1.procedure.id }.uniq)
        .index_by(&:procedure_id)
      return if @personnalisations_by_procedure_id.empty?

      stable_ids = @personnalisations_by_procedure_id.values
        .flat_map(&:displayed_columns)
        .filter(&:champ_column?)
        .map(&:stable_id)
        .uniq
      return if stable_ids.empty?

      ChampData.where(dossier_id: dossiers.map(&:id), stable_id: stable_ids, stream: Dossier::MAIN_STREAM)
        .find_each do |champ|
          (@champs_by_dossier_id[champ.dossier_id] ||= {})[champ.stable_id] = champ
        end
    end

    # Sur-ensemble des dossiers ayant des champs sur le stream « user:buffer » :
    # une seule requête pour toute la page, au lieu de charger tous les champs
    # de chaque dossier en_construction juste pour décider d'afficher la bannière
    # « modifications non soumises ». Le composant fait ensuite la vérification
    # précise (stable_id dans la révision) sur les seuls dossiers signalés.
    def load_user_buffer_changes_data(dossiers)
      dossier_ids = dossiers.filter(&:en_construction?).map(&:id)
      @dossier_ids_with_user_buffer_changes = ChampData
        .where(dossier_id: dossier_ids, stream: Dossier::USER_BUFFER_STREAM)
        .distinct
        .pluck(:dossier_id)
        .to_set
    end

    def personnalisation_available?
      feature_enabled?(:dossiers_list_personnalisation) &&
        dossier_filter.user_dossiers.count > SIMPLE_LIST_THRESHOLD
    end

    def dossier_filter
      @filter ||= Users::DossierFilterService.new(user: current_user, params:)
    end

    def user_procedures
      Procedure.where(id: dossier_filter.user_dossiers.joins(:procedure).select('procedures.id'))
    end

    def personnalisation_params
      params.permit(personnalisations: {}).fetch(:personnalisations, {}).to_h
    end

    def personnalisable_procedures
      user_procedures
        .distinct
        .order(:libelle)
        .includes(published_revision: { revision_types_de_champ: :type_de_champ })
        .filter { _1.customizable_columns_by_section.any? }
    end

    def redirect_if_hidden_or_deleted_dossier
      dossier_id = params[:id]

      if hidden_dossier_for(dossier_id)
        return redirect_to corbeille_dossier_path(dossier_id)
      elsif deleted_dossier_for(dossier_id)
        return redirect_to supprime_dossier_path(dossier_id)
      end
    end

    def hidden_dossier_for(dossier_id)
      current_user.dossiers
        .hidden_by_user
        .find_by(id: dossier_id)
    end

    def deleted_dossier_for(dossier_id)
      DeletedDossier.find_by(dossier_id:, user_id: current_user.id)
    end

    def set_default_value_for_france_connect_champs
      @dossier.set_default_value_for_france_connect_champs(current_user.email)
    end

    def prefill_champs_from_france_connect
      @dossier.prefill_champs_from_france_connect(updated_by: current_user.email)
    end
  end
end
