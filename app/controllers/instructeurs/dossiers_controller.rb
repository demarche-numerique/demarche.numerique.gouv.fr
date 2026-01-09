# frozen_string_literal: true

module Instructeurs
  class DossiersController < ProceduresController
    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::TextHelper
    include DossierHelper
    include AvisCreationConcern
    include TurboChampsConcern
    include InstructeurConcern
    include ActionController::Streaming
    include Zipline

    before_action :redirect_on_dossier_not_found, only: :show
    before_action :redirect_on_dossier_in_batch_operation, only: [:archive, :unarchive, :follow, :unfollow, :passer_en_instruction, :repasser_en_construction, :repasser_en_instruction, :terminer, :restore, :destroy, :extend_conservation]
    before_action :dossier_with_champs, only: [:show]
    before_action :set_gallery_attachments, only: [:show, :pieces_jointes, :annotations_privees, :avis, :messagerie, :personnes_impliquees, :reaffectation, :rendez_vous, :rdv_connection]
    before_action :retrieve_procedure_presentation, only: [:annotations_privees, :avis_new, :avis, :messagerie, :personnes_impliquees, :pieces_jointes, :reaffectation, :rendez_vous, :rdv_connection, :show, :dossier_labels, :passer_en_instruction, :repasser_en_construction, :repasser_en_instruction, :terminer, :pending_correction, :create_avis, :create_commentaire]
    before_action :set_notifications, only: [:show, :annotations_privees, :avis, :avis_new, :messagerie, :personnes_impliquees, :pieces_jointes, :reaffectation, :rendez_vous, :rdv_connection, :dossier_labels, :repasser_en_construction, :repasser_en_instruction, :create_avis, :create_commentaire]

    after_action :mark_demande_as_read, only: :show
    after_action :mark_messagerie_as_read, only: [:messagerie, :create_commentaire, :pending_correction]
    after_action :mark_avis_as_read, only: [:avis]
    after_action :mark_annotations_privees_as_read, only: [:annotations_privees, :update_annotations]
    after_action -> { destroy_notification(:dossier_modifie) }, only: [:show], if: -> { @notifications.any?(&:dossier_modifie?) }
    after_action -> { destroy_notification(:message) }, only: [:messagerie], if: -> { @notifications.any?(&:message?) }
    after_action -> { destroy_notification(:annotation_instructeur) }, only: [:annotations_privees], if: -> { @notifications.any?(&:annotation_instructeur?) }
    after_action -> { destroy_notification(:avis_externe) }, only: [:avis], if: -> { @notifications.any?(&:avis_externe?) }

    def extend_conservation
      dossier.extend_conservation(1.month)
      flash[:notice] = t('views.instructeurs.dossiers.archived_dossier')
      redirect_back(fallback_location: instructeur_dossier_path(@dossier.procedure, @dossier))
    end

    def extend_conservation_and_restore
      dossier.extend_conservation_and_restore(1.month, current_instructeur)
      flash[:notice] = t('views.instructeurs.dossiers.archived_dossier')
      redirect_back(fallback_location: instructeur_dossier_path(@dossier.procedure, @dossier))
    end

    def geo_data
      send_data dossier.to_feature_collection.to_json,
        type: 'application/json',
        filename: "dossier-#{dossier.id}-features.json"
    end

    def apercu_attestation
      attestation_kind = params[:attestation_kind]
      send_data dossier.attestation_template_for(attestation_kind).send(:build_pdf, dossier),
                  filename: 'attestation.pdf',
                  type: 'application/pdf',
                  disposition: 'inline'
    end

    def bilans_bdf
      extension = params[:format]
      render extension.to_sym => dossier.etablissement.entreprise_bilans_bdf_to_sheet(extension)
    end

    def show
      @demande_seen_at = current_instructeur.follows.find_by(dossier: dossier_with_champs)&.demande_seen_at
      @is_dossier_in_batch_operation = dossier.batch_operation.present?
      respond_to do |format|
        format.pdf do
          @acls = PiecesJustificativesService.new(user_profile: current_instructeur, export_template: nil).acl_for_dossier_export(dossier.procedure)
          render(template: 'dossiers/show', formats: [:pdf])
        end
        format.all
      end
    end

    def dossier_labels
      labels = params[:label_id]&.map(&:to_i) || []

      @dossier = dossier
      labels.each { |params_label| DossierLabel.find_or_create_by(dossier_id: @dossier.id, label_id: params_label) }

      all_labels = DossierLabel.where(dossier_id: @dossier.id).pluck(:label_id)

      (all_labels - labels).each { DossierLabel.find_by(dossier_id: @dossier.id, label_id: _1).destroy }

      render :change_state
    end

    def messagerie
      @commentaire = Commentaire.new
      @messagerie_seen_at = current_instructeur.follows.find_by(dossier: dossier)&.messagerie_seen_at
    end

    def annotations_privees
      @annotations_privees_seen_at = current_instructeur.follows.find_by(dossier: dossier)&.annotations_privees_seen_at
    end

    def avis
      @avis_seen_at = current_instructeur.follows.find_by(dossier: dossier)&.avis_seen_at
      @avis = Avis.new
      @experts_emails = Expert.autocomplete_mails(@dossier.procedure)
    end

    def avis_new
      @avis_seen_at = current_instructeur.follows.find_by(dossier: dossier)&.avis_seen_at
      @avis = Avis.new
      @experts_emails = Expert.autocomplete_mails(@dossier.procedure)
    end

    def personnes_impliquees
      # sort following_instructeurs (last follower on top) for the API of Agence de l’Eau Loire-Bretagne
      @following_instructeurs_emails = dossier.followers_instructeurs.joins(:follows).merge(Follow.order(id: :desc)).map(&:email)
      previous_followers = dossier.previous_followers_instructeurs - dossier.followers_instructeurs
      @previous_following_instructeurs_emails = previous_followers.map(&:email)
      @avis_emails = dossier.experts.map(&:email)
      @invites_emails = dossier.invites.map(&:email)
      @potential_recipients = dossier.groupe_instructeur.instructeurs.reject { |g| g == current_instructeur }
      @manual_assignments = dossier.dossier_assignments.manual.includes(:groupe_instructeur, :previous_groupe_instructeur)
    end

    def rendez_vous
      return if current_instructeur.rdv_connection.nil?

      rdv_service = RdvService.new(rdv_connection: current_instructeur.rdv_connection)

      rdv_service.update_pending_rdv_plan!(dossier:)

      @booked_rdvs = rdv_service.list_rdvs(dossier.rdvs.booked.pluck(:rdv_external_id))
      @rdv_email = RdvService.new(rdv_connection: current_instructeur.rdv_connection).get_account_info["email"]
    end

    def rdv_connection
    end

    def send_to_instructeurs
      recipients = params['recipients'].presence || []
      # instructeurs are scoped by groupe_instructeur to avoid enumeration
      recipients = dossier.groupe_instructeur.instructeurs.where(id: recipients)

      if recipients.present?
        recipients.each do |recipient|
          recipient.follow(dossier)
          InstructeurMailer.send_dossier(current_instructeur, dossier, recipient).deliver_later
        end
        flash.notice = "Dossier envoyé"
      else
        flash.alert = "Instructeur inconnu ou non présent sur la procédure"
      end

      redirect_to(personnes_impliquees_instructeur_dossier_path(procedure, dossier))
    end

    def follow
      current_instructeur.follow(dossier)

      flash.notice = 'Dossier suivi'

      redirect_back(fallback_location: instructeur_procedure_path(procedure))
    end

    def unfollow
      current_instructeur.unfollow(dossier)

      flash.notice = "Vous ne suivez plus le dossier n° #{dossier.id}"

      redirect_back(fallback_location: instructeur_procedure_path(procedure))
    end

    def archive
      dossier.archiver!(current_instructeur)
      redirect_back(fallback_location: instructeur_procedure_path(procedure))
    end

    def unarchive
      dossier.desarchiver!
      redirect_back(fallback_location: instructeur_procedure_path(procedure))
    end

    def passer_en_instruction
      begin
        dossier.passer_en_instruction!(instructeur: current_instructeur)
        flash.notice = 'Dossier passé en instruction.'
      rescue AASM::InvalidTransition => e
        flash.alert = aasm_error_message(e, target_state: :en_instruction)
      end

      @dossier = dossier
      respond_to do |format|
        format.turbo_stream do
          set_notifications
          render :change_state
        end

        format.html do
          redirect_back(fallback_location: instructeur_procedure_path(procedure))
        end
      end
    end

    def repasser_en_construction
      begin
        dossier.repasser_en_construction!(instructeur: current_instructeur)
        flash.notice = 'Dossier repassé en construction.'
      rescue AASM::InvalidTransition => e
        flash.alert = aasm_error_message(e, target_state: :en_construction)
      end

      @dossier = dossier
      respond_to do |format|
        format.turbo_stream do
          render :change_state
        end

        format.html do
          redirect_back(fallback_location: instructeur_procedure_path(procedure))
        end
      end
    end

    def repasser_en_instruction
      begin
        flash.notice = "Le dossier #{dossier.id} a été repassé en instruction."
        dossier.repasser_en_instruction!(instructeur: current_instructeur)
      rescue AASM::InvalidTransition => e
        flash.alert = aasm_error_message(e, target_state: :en_instruction)
      end

      @dossier = dossier
      respond_to do |format|
        format.turbo_stream do
          render :change_state
        end

        format.html do
          redirect_back(fallback_location: instructeur_procedure_path(procedure))
        end
      end
    end

    def terminer
      motivation = params[:dossier] && params[:dossier][:motivation]
      justificatif = params[:dossier] && params[:dossier][:justificatif_motivation]

      h = { instructeur: current_instructeur, motivation: motivation, justificatif: justificatif }

      begin
        case params[:process_action]
        when "refuser"
          target_state = :refuse
          dossier.refuser!(h)
          flash.notice = "Dossier considéré comme refusé."
        when "classer_sans_suite"
          target_state = :sans_suite
          dossier.classer_sans_suite!(h)
          flash.notice = "Dossier considéré comme sans suite."
        when "accepter"
          target_state = :accepte
          dossier.accepter!(h)
          flash.notice = "Dossier traité avec succès."
        end
      rescue AASM::InvalidTransition => e
        flash.alert = aasm_error_message(e, target_state: target_state)
      end

      @dossier = dossier
      set_notifications
      render :change_state
    end

    def pending_correction
      message, piece_jointe = params.require(:dossier).permit(:motivation, :justificatif_motivation).values

      if message.empty?
        flash.alert = "Vous devez préciser quelle correction est attendue."
      elsif !dossier.may_flag_as_pending_correction?
        flash.alert = dossier.termine? ? "Impossible de demander de corriger un dossier terminé." : "Le dossier est déjà en attente de correction."
      else
        commentaire = CommentaireService.build(current_instructeur, dossier, { body: message, piece_jointe: })

        if commentaire.valid?
          dossier.flag_as_pending_correction!(commentaire, params[:reason].presence)
          dossier.touch(:last_commentaire_updated_at)
          current_instructeur.follow(dossier)

          flash.notice = "Dossier marqué comme en attente de correction."
        else
          flash.alert = commentaire.errors.full_messages.map { "Commentaire : #{_1}" }
        end
      end

      respond_to do |format|
        format.turbo_stream do
          @dossier = dossier
          set_notifications
          render :change_state
        end

        format.html do
          redirect_back(fallback_location: instructeur_procedure_path(procedure))
        end
      end
    end

    def create_commentaire
      @commentaire = CommentaireService.create(current_instructeur, dossier, commentaire_params)

      if @commentaire.errors.empty?
        @commentaire.dossier.touch(:last_commentaire_updated_at)
        current_instructeur.follow(dossier)
        DossierNotification.create_notification(dossier, :message, except_instructeur: current_instructeur)

        handle_pending_response_flag(@commentaire)

        redirect_to messagerie_instructeur_dossier_path(procedure, dossier, statut: statut)
      else
        @commentaire.piece_jointe.purge.reload # only allowed here, sync action
        flash.alert = @commentaire.errors.full_messages
        render :messagerie
      end
    end

    def create_avis
      @dossier = dossier
      @procedure = dossier.procedure

      @new_avis = Avis.new(dossier: @dossier) # <- utilisé si le form échoue

      handle_create_avis(
        dossier: @dossier,
        user: current_instructeur,
        params: avis_create_params,
        success_path: avis_instructeur_dossier_path(@procedure, @dossier, statut: statut),
        error_template: :avis_new
      )
    end

    def update_annotations
      public_id, annotation_attributes = champs_private_attributes_params.to_h.first
      annotation = dossier.private_champ_for_update(public_id, updated_by: current_user.email)
      if annotation.referentiel? && annotation.autocomplete?
        annotation_attributes = annotation_attributes.merge(params.require(:dossier).require(:champs_private_attributes).require(public_id).permit(:data).to_h)
      end
      annotation.assign_attributes(annotation_attributes)
      annotation_changed = annotation.changed_for_autosave?

      if annotation_changed && annotation.save
        annotation.update_timestamps

        if annotation.uses_external_data?
          annotation.reset_external_data!
          annotation.fetch_later! if annotation.may_fetch_later?
        end

        dossier.index_search_terms_later
        DossierNotification.create_notification(dossier, :annotation_instructeur, except_instructeur: current_instructeur) if !dossier.brouillon?
      end

      dossier.validate(:champs_private_value) if !annotation.pending?

      respond_to do |format|
        format.turbo_stream do
          @to_show, @to_hide, @to_update = champs_to_turbo_update(champs_private_attributes_params, dossier.project_champs_private_all)
        end
      end
    end

    def print
      @dossier = dossier
      render layout: "print"
    end

    def annotation
      @dossier = dossier_with_champs
      type_de_champ = @dossier.find_type_de_champ_by_stable_id(params[:stable_id], :private)
      annotation = @dossier.project_champ(type_de_champ, row_id: params[:row_id])
      annotation.validate(:champs_public_value) if annotation.done?

      respond_to do |format|
        format.turbo_stream do
          @to_show, @to_hide = []
          @to_update = [annotation].concat(annotation.prefillable_champs)

          render :update_annotations
        end
      end
    end

    def telecharger_pjs
      files = ActiveStorage::DownloadableFile.create_list_from_dossiers(dossiers: Dossier.where(id: dossier.id), user_profile: current_instructeur)
      cleaned_files = ActiveStorage::DownloadableFile.cleanup_list_from_dossier(files)

      zipline(cleaned_files, "dossier-#{dossier.id}.zip")
    end

    def destroy
      if dossier.termine?
        dossier.hide_and_keep_track!(current_instructeur, :instructeur_request)
        flash.notice = t('instructeurs.dossiers.deleted_by_instructeur')
      else
        flash.alert = t('instructeurs.dossiers.impossible_deletion')
      end
      redirect_back(fallback_location: instructeur_procedure_path(procedure))
    end

    def restore
      dossier = current_instructeur.dossiers.find(params[:dossier_id])
      dossier.restore(current_instructeur)
      flash.notice = t('instructeurs.dossiers.restore')

      if dossier.termine?
        redirect_to instructeur_procedure_path(procedure, statut: :traites)
      else
        redirect_back(fallback_location: instructeur_procedure_path(procedure))
      end
    end

    def reaffectation
      @dossier = current_instructeur.dossiers.find(params[:dossier_id]).with_champs

      @groupe_instructeur = @dossier.groupe_instructeur

      @groupes_instructeurs = @groupe_instructeur.other_groupe_instructeurs
    end

    def reaffecter
      dossier = current_instructeur.dossiers.find(params[:dossier_id])

      new_group = dossier
        .procedure
        .groupe_instructeurs.find_by(id: params[:groupe_instructeur_id])

      if new_group.present?
        dossier.assign_to_groupe_instructeur(new_group, DossierAssignment.modes.fetch(:manual), current_instructeur)

        flash.notice = t('instructeurs.dossiers.reaffectation.success', dossier_id: dossier.id, label: new_group.label)
        redirect_to instructeur_procedure_path(procedure)
      else
        flash.alert = t('instructeurs.dossiers.reaffectation.error')
        redirect_to reaffectation_instructeur_dossier_path(dossier.procedure, dossier)
      end
    end

    def pieces_jointes
      @dossier = dossier
    end

    def next
      navigate_through_dossiers_list do |cache|
        cache.next_dossier_id(from_id: params[:dossier_id])
      end
    end

    def previous
      navigate_through_dossiers_list do |cache|
        cache.previous_dossier_id(from_id: params[:dossier_id])
      end
    end

    private

    def handle_pending_response_flag(commentaire)
      if params[:mark_as_pending_response] == 'true'
        dossier.flag_as_pending_response!(commentaire)
        flash.notice = t('instructeurs.dossiers.message_sent_with_pending_response')
      else
        flash.notice = t('instructeurs.dossiers.message_sent')
      end
    end

    def avis_create_params
      params.require(:avis).permit(
        :introduction_file,
        :introduction,
        :confidentiel,
        :invite_linked_dossiers,
        :question_label,
        emails: []
      )
    end

    def navigate_through_dossiers_list
      dossier = dossier_scope.find(params[:dossier_id])
      procedure_presentation = current_instructeur.procedure_presentation_for_procedure_id(dossier.procedure.id)
      cache = Cache::ProcedureDossierPagination.new(procedure_presentation:, statut: params[:statut])

      next_or_previous_dossier_id = yield(cache)

      if next_or_previous_dossier_id
        redirect_to instructeur_dossier_path(procedure_id: procedure.id, dossier_id: next_or_previous_dossier_id, statut: params[:statut])
      else
        redirect_back fallback_location: instructeur_dossier_path(procedure_id: procedure.id, dossier_id: dossier.id, statut: params[:statut]), alert: "Une erreur est survenue"
      end
    rescue ActiveRecord::RecordNotFound
      Sentry.capture_message(
        "Navigation through dossier failed => ActiveRecord::RecordNotFound",
        extra: { dossier_id: params[:dossier_id] }
      )
      redirect_to instructeur_procedure_path(procedure_id: procedure.id), alert: "Une erreur est survenue"
    end

    def dossier_scope
      if action_name == 'update_annotations'
        Dossier
          .where(id: current_instructeur.dossiers.visible_by_administration)
          .or(Dossier.where(id: current_user.dossiers.for_procedure_preview))
      elsif action_name == 'extend_conservation_and_restore'
        Dossier
          .where(id: current_instructeur.dossiers.visible_by_administration)
          .or(Dossier.where(id: current_instructeur.dossiers.hidden_by_expired))
      else
        current_instructeur.dossiers.visible_by_administration
      end
    end

    def dossier
      @dossier ||= DossierPreloader.load_one(dossier_scope.find(params[:dossier_id])).tap do
        set_sentry_dossier(_1)
      end
    end

    def dossier_with_champs
      @dossier ||= DossierPreloader.load_one(dossier_scope.find(params[:dossier_id]), pj_template: true)
    end

    def commentaire_params
      params.require(:commentaire).permit(:body, piece_jointe: [])
    end

    def champs_private_params
      champ_attributes = [
        :id,
        :value,
        :value_other,
        :external_id,
        :code,
        :primary_value,
        :secondary_value,
        :numero_allocataire,
        :code_postal,
        :identifiant,
        :numero_fiscal,
        :reference_avis,
        :ine,
        :piece_justificative_file,
        :code_departement,
        :accreditation_number,
        :accreditation_birthdate,
        :address,
        :not_in_ban,
        :street_address,
        :city_name,
        :country_code,
        :commune_code,
        :postal_code,
        value: [],
      ]
      # Strong attributes do not support records (indexed hash); they only support hashes with
      # static keys. We create a static hash based on the available keys.
      public_ids = params.dig(:dossier, :champs_private_attributes)&.keys || []
      champs_private_attributes = public_ids.index_with { champ_attributes }
      params.require(:dossier).permit(champs_private_attributes:)
    end

    def champs_private_attributes_params
      champs_private_params.fetch(:champs_private_attributes)
    end

    def mark_demande_as_read
      current_instructeur.mark_tab_as_seen(dossier, :demande)
    end

    def mark_messagerie_as_read
      current_instructeur.mark_tab_as_seen(dossier, :messagerie)
      Commentaire.mark_usager_messages_as_seen(dossier)
    end

    def mark_avis_as_read
      current_instructeur.mark_tab_as_seen(dossier, :avis)
    end

    def mark_annotations_privees_as_read
      current_instructeur.mark_tab_as_seen(dossier, :annotations_privees)
    end

    def aasm_error_message(exception, target_state:)
      if exception.originating_state == target_state
        "Le dossier est déjà #{dossier_display_state(target_state, lower: true)}."
      elsif exception.failures.include?(:can_terminer?) && dossier.any_etablissement_as_degraded_mode?
        "Les données relatives au SIRET de ce dossier n’ont pas pu encore être vérifiées : il n’est pas possible de le passer en #{dossier_display_state(target_state, lower: true)}."
      elsif exception.failures.include?(:can_terminer?) && dossier.any_annotations_privees_with_errors?
        t('instructeurs.dossiers.aasm_error_annotations', url: annotations_privees_instructeur_dossier_path(dossier.procedure, dossier, statut: params[:statut]), state: dossier_display_state(target_state, lower: true))
      else
        "Le dossier est en ce moment #{dossier_display_state(exception.originating_state, lower: true)} : il n’est pas possible de le passer #{dossier_display_state(target_state, lower: true)}."
      end
    end

    def redirect_on_dossier_not_found
      if !dossier_scope.exists?(id: params[:dossier_id])
        redirect_to instructeur_procedure_path(procedure)
      end
    end

    def redirect_on_dossier_in_batch_operation
      dossier_in_batch = begin
        dossier
                         rescue ActiveRecord::RecordNotFound
                           current_instructeur.dossiers.find(params[:dossier_id])
      end
      if dossier_in_batch.batch_operation.present?
        flash.alert = "Votre action n’a pas été effectuée, ce dossier fait parti d’un traitement de masse."
        redirect_back(fallback_location: instructeur_dossier_path(procedure, dossier_in_batch))
      end
    end

    def set_gallery_attachments
      gallery_attachments_ids = Rails.cache.fetch([dossier, "gallery_attachments"], expires_in: 10.minutes) do
        champs_attachments_ids = dossier
          .filled_champs
          .filter(&:piece_justificative_or_titre_identite?)
          .filter(&:visible?)
          .flat_map(&:piece_justificative_file)
          .map(&:id)

        commentaires_attachments_ids = dossier
          .commentaires
          .includes(piece_jointe_attachments: :blob)
          .map(&:piece_jointe)
          .flat_map(&:attachments)
          .map(&:id)

        avis_attachments_ids = dossier
          .avis.flat_map { [_1.introduction_file, _1.piece_justificative_file] }
          .flat_map(&:attachments)
          .compact
          .map(&:id)

        justificatif_motivation_id = dossier
          .justificatif_motivation
          &.attachment
          &.id

        attestation_id = dossier
          .attestation
          &.pdf
          &.id

        champs_attachments_ids + commentaires_attachments_ids + avis_attachments_ids + [justificatif_motivation_id] + [attestation_id]
      end

      @gallery_attachments = ActiveStorage::Attachment
        .with_all_variant_records
        .includes(:record, :blob)
        .where(id: gallery_attachments_ids)
    end
  end
end
