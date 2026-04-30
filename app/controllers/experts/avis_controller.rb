# frozen_string_literal: true

module Experts
  class AvisController < ExpertController
    include BilansBdfConcern
    include Zipline
    include AvisCreationConcern

    before_action :authenticate_expert!, except: [:sign_up, :update_expert]
    before_action :check_if_avis_revoked, except: [:index, :procedure, :notification_settings, :update_notification_settings, :sign_up, :update_expert]
    before_action :redirect_if_no_sign_up_needed, only: [:sign_up, :update_expert]
    before_action :set_avis_and_dossier, only: [:show, :instruction, :avis_list, :avis_new, :create_avis, :messagerie, :create_commentaire, :update, :telecharger_pjs]
    before_action :check_messaging_allowed, only: [:messagerie, :create_commentaire]
    before_action :set_procedure, only: [:notification_settings, :update_notification_settings]

    A_DONNER_STATUS = 'a-donner'
    DONNES_STATUS   = 'donnes'

    def index
      avis = current_expert.avis
        .not_revoked
        .includes(:dossier, :procedure)
        .not_hidden_by_administration
      @avis_by_procedure = avis.to_a.group_by(&:procedure)
    end

    def procedure
      @procedure = current_expert.procedures.find_by(id: params[:procedure_id])

      if @procedure.nil?
        redirect_to(expert_all_avis_path, flash: { alert: "Vous n’avez pas accès à cette démarche." }) and return
      end

      expert_avis = current_expert
        .avis
        .not_revoked
        .includes(:procedure)
        .includes(dossier: :user)
        .not_hidden_by_administration
        .where(dossiers: { groupe_instructeur: GroupeInstructeur.where(procedure: @procedure) })

      if expert_avis.empty?
        redirect_to(expert_all_avis_path, flash: { alert: "Vous n’avez pas accès à cette démarche." }) and return
      end

      @avis_a_donner = expert_avis.not_termine.without_answer
      @avis_donnes = expert_avis.with_answer

      @statut = params[:statut].presence || A_DONNER_STATUS

      @avis = case @statut
      when A_DONNER_STATUS
        @avis_a_donner
      when DONNES_STATUS
        @avis_donnes
      end
      @avis = @avis.by_latest
      @avis = @avis.page([params[:page].to_i, 1].max)
    end

    def show
      @dossier = dossier_with_champs
    end

    def instruction
      @new_avis = Avis.new
    end

    def avis_list
    end

    def expert_procedure
      ExpertsProcedure.find_by!(expert_id: current_expert.id, procedure_id: @procedure.id)
    end

    def notification_settings
      @expert_procedure = expert_procedure
    end

    def update_notification_settings
      expert_procedure.update!(expert_procedure_params)
      flash.notice = 'Vos notifications sont enregistrées.'
      redirect_to procedure_expert_avis_index_path(@procedure)
    end

    def avis_new
      @new_avis = Avis.new
      @experts_emails = Expert.autocomplete_mails(@dossier.procedure)
    end

    def create_avis
      # before_action set_avis_and_dossier
      @procedure = @avis.procedure
      @new_avis = Avis.new

      handle_create_avis(
        dossier: @dossier,
        user: current_expert,
        params: avis_create_params,
        success_path: instruction_expert_avis_path(@procedure, @avis),
        error_template: :instruction,
        avis_source: @avis
      )
    end

    def update
      was_unanswered = @avis.answer.nil?
      updated_recently = @avis.updated_recently?
      if @avis.update(avis_answer_params)
        flash.notice = 'Votre réponse est enregistrée.'

        timestamps = [:last_avis_updated_at, :updated_at]
        timestamps << :last_avis_piece_jointe_updated_at if @avis.piece_justificative_file.attached?

        @avis.dossier.touch(*timestamps)

        DossierNotification.destroy_notifications_by_dossier_and_type(@avis.dossier, :attente_avis) if @avis.dossier.avis.without_answer.empty?
        DossierNotification.create_notification(@avis.dossier, :avis_externe)

        if was_unanswered || !updated_recently
          @avis.dossier.followers_instructeurs
            .with_instant_email_new_expert_avis(@avis.procedure)
            .each do |instructeur|
            DossierMailer.notify_new_avis_to_instructeur(@avis, instructeur.email).deliver_later
          end
        end
        redirect_to instruction_expert_avis_path(@avis.procedure, @avis)
      else
        flash.now.alert = @avis.errors.full_messages
        @new_avis = Avis.new
        render :instruction
      end
    end

    def sign_up
      @email = params[:email]
      @confirmation_token = params[:confirmation_token]
      @dossier = Avis.includes(:dossier).find(params[:id]).dossier

      render
    end

    def update_expert
      procedure_id = params[:procedure_id]
      avis_id = params[:id]
      email = params[:email]
      confirmation_token = params.dig(:user, :confirmation_token).presence
      if confirmation_token.nil?
        return redirect_to root_path, alert: "Vous n’avez pas accès à cet avis."
      end

      avis = Avis.joins(:procedure, expert: :user)
        .find_by(id: avis_id, procedure: { id: procedure_id }, user: { email:, confirmation_token: })
      if avis.nil?
        return redirect_to root_path, alert: "Vous n’avez pas accès à cet avis."
      end

      password = params.require(:user).permit(:password)[:password]
      user = User.create_or_promote_to_expert(email, password)
      user.reset_password(password, password)

      if user.valid?
        sign_in(user)
        user.update!(email_verified_at: Time.zone.now) if user.unverified_email?
        redirect_to url_for(expert_all_avis_path)
      else
        flash[:alert] = user.errors.full_messages
        redirect_to sign_up_expert_avis_path(procedure_id, avis_id, email: email)
      end
    end

    def messagerie
      @commentaire = Commentaire.new
    end

    def create_commentaire
      @commentaire = CommentaireService.create(current_expert, avis.dossier, commentaire_params)

      if @commentaire.errors.empty?
        timestamps = [:last_commentaire_updated_at, :updated_at]
        timestamps << :last_commentaire_piece_jointe_updated_at if @commentaire.piece_jointe.attached?

        @commentaire.dossier.touch(*timestamps)
        DossierNotification.create_notification(avis.dossier, :message)

        flash.notice = "Message envoyé"

        respond_to do |format|
          format.turbo_stream do
            @dossier = avis.dossier
            @connected_user = current_expert
            @form_url = commentaire_expert_avis_path(avis)
            render template: 'shared/dossiers/create_commentaire'
          end
          format.html { redirect_to messagerie_expert_avis_path(avis.procedure, avis) }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            @dossier = avis.dossier
            @connected_user = current_expert
            @form_url = commentaire_expert_avis_path(avis)
            render template: 'shared/dossiers/create_commentaire', status: :unprocessable_entity
          end
          format.html do
            flash.alert = @commentaire.errors.full_messages
            render :messagerie, status: :unprocessable_entity
          end
        end
      end
    end

    def bilans_bdf
      bilans_bdf_response(avis.dossier.etablissement, params[:format], expert_avis_path(avis))
    end

    def telecharger_pjs
      files = ActiveStorage::DownloadableFile.create_list_from_dossiers(user_profile: current_expert, dossiers: Dossier.where(id: @dossier.id))
      cleaned_files = ActiveStorage::DownloadableFile.cleanup_list_from_dossier(files)

      zipline(cleaned_files, "dossier-#{@dossier.id}.zip")
    end

    private

    def expert_procedure_params
      params.require(:experts_procedure)
        .permit(:notify_on_new_avis, :notify_on_new_message)
    end

    def set_procedure
      @procedure = current_expert.procedures.find(params[:procedure_id])
    end

    def check_messaging_allowed
      if !@avis.procedure.allow_expert_messaging
        flash[:alert] = "Vous n'êtes pas autorisé à acceder à la messagerie"
        redirect_to expert_avis_url(avis.procedure, avis)
      end
    end

    def redirect_if_no_sign_up_needed
      avis = Avis.find(params[:id])
      submitted_token = params[:confirmation_token] || params.dig(:user, :confirmation_token)

      if current_expert.present?
        # an expert is authenticated ... lets see if it can view the dossier
        redirect_to expert_avis_url(avis.procedure, avis)
      elsif avis.expert&.email == params[:email] &&
            avis.expert.user.confirmation_token.present? &&
            avis.expert.user.confirmation_token == submitted_token &&
            avis.expert.user.active?
        # The expert already used the sign-in page to change their password: ask them to sign-in instead.
        redirect_to new_user_session_url
      end
    end

    def avis
      current_expert.avis.includes(dossier: [:avis, :commentaires]).find(params[:id])
    end

    def check_if_avis_revoked
      avis = Avis.find(params[:id])
      if avis.revoked?
        flash.alert = "Vous n’avez plus accès à ce dossier."
        redirect_to url_for(root_path)
      end
    end

    def set_avis_and_dossier
      @avis = current_expert.avis.find_by(id: params[:id])
      unless @avis
        redirect_to expert_all_avis_path, flash: { alert: "Vous n’avez pas accès à cet avis." } and return
      end
      @dossier = @avis.dossier
      set_sentry_dossier(@dossier)
    end

    def dossier_with_champs
      DossierPreloader.load_one(@dossier, pj_template: false)
    end

    def avis_answer_params
      params.require(:avis).permit(:answer, :piece_justificative_file, :question_answer)
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

    def commentaire_params
      params.require(:commentaire).permit(:body, piece_jointe: [])
    end
  end
end
