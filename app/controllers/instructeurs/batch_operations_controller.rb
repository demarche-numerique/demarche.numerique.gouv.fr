# frozen_string_literal: true

module Instructeurs
  class BatchOperationsController < ApplicationController
    before_action :set_procedure
    before_action :ensure_ownership!

    def create
      operation = params.dig(:batch_operation, :operation)
      motivation = params.dig(:batch_operation, :motivation)

      if operation.in?(%w[refuser classer_sans_suite]) && motivation.blank?
        flash.alert = t('instructeurs.dossiers.motivation_missing_error')
        return redirect_back_or_to(instructeur_procedure_url(@procedure.id))
      end

      batch = BatchOperation.safe_create!(batch_operation_params)
      flash[:alert] = "Le traitement de masse n’a pas été lancé. Vérifiez que l’action demandée est possible pour les dossiers sélectionnés" if batch.blank?
      redirect_back_or_to(instructeur_procedure_url(@procedure.id))
    end

    def create_batch_avis
      emails = Array(avis_create_params[:emails]).map(&:strip).map(&:downcase).compact_blank
      email_regex = StrictEmailValidator::REGEXP

      invalid_emails = emails.filter { |email| email.present? && !(email =~ email_regex) }

      avis = Avis.new(avis_create_params.except(:emails))
      email_label = User.human_attribute_name(:email)

      if emails.empty?
        avis.errors.add(:base, format(t('errors.format'), attribute: email_label, message: t('errors.messages.blank')))
      end

      invalid_emails.each do |email|
        avis.errors.add(:base, format(t('errors.format'), attribute: email_label, message: "est invalide : #{email}"))
      end

      batch = avis.errors.empty? ? BatchOperation.safe_create!(batch_operation_avis_params) : nil

      respond_to do |format|
        format.turbo_stream do
          if batch.nil?
            @ids = submitted_dossier_ids

            render turbo_stream: turbo_stream.replace("modal-avis-batch-form", partial: "shared/avis/form_wrapper",
              locals: {
                url:  create_batch_avis_instructeur_batch_operations_path(procedure_id: @procedure.id),
                linked_dossiers: '',
                must_be_confidentiel: false,
                avis: avis,
                batch_action: true,
                procedure: @procedure,
                dossier_ids: @ids,
              })
          else
            render turbo_stream: turbo_stream.append(
              "contenu",
              partial: "shared/redirect_and_close_modal",
              locals: {
                redirect_url: instructeur_procedure_path(@procedure, statut: 'suivis'),
              }
            )
          end
        end

        format.html do
          flash[:alert] = "Le traitement de masse n’a pas été lancé. Vérifiez que l’action demandée est possible pour les dossiers sélectionnés" if batch.blank?
          redirect_back_or_to(instructeur_procedure_url(@procedure.id))
        end
      end
    end

    def batch_instruction_modal
      @operation = params[:operation]
      @dossier_ids = params[:dossier_ids] || []
      @modal_title_data = helpers.instruction_modal_title_data(batch: true)

      respond_to do |format|
        format.turbo_stream
      end
    end

    def create_batch_commentaire
      dossier_ids = batch_operation_commentaire_params[:dossier_ids]

      if dossier_ids&.size&.> BatchOperation::BATCH_SELECTION_LIMIT
        flash.alert = t('.batch_selection_limit_exceeded', limit: BatchOperation::BATCH_SELECTION_LIMIT)
        render_redirect_and_close_modal and return
      end

      batch = BatchOperation.safe_create!(batch_operation_commentaire_params)
      commentaire = Commentaire.new(commentaire_params)

      respond_to do |format|
        format.turbo_stream do
          if batch.blank? || commentaire.errors.any?
            render_commentaire_form_with_errors(commentaire)
          else
            render_redirect_and_close_modal and return
          end
        end

        format.html do
          flash[:alert] = t('.batch_creation_failed') if batch.blank?
          redirect_back_or_to(instructeur_procedure_url(@procedure.id))
        end
      end
    end

    private

    def batch_operation_params
      params.require(:batch_operation)
        .permit(:operation, :motivation, :justificatif_motivation, dossier_ids: [])
        .merge(dossier_ids: submitted_dossier_ids)
        .merge(instructeur: current_instructeur)
    end

    # The form sends either a list of ids, or a list of comma-joined ids — and
    # nothing at all when no dossier is selected.
    def submitted_dossier_ids
      Array(params.dig(:batch_operation, :dossier_ids)).flat_map do |value|
        value.is_a?(String) ? value.split(',') : value
      end.compact_blank.uniq
    end

    def batch_operation_avis_params
      params.require(:batch_operation).permit(dossier_ids: []).tap do |batch_params|
        batch_params[:operation] = 'create_avis'
        batch_params[:instructeur] = current_instructeur
        batch_params.merge!(avis_create_params)
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

    def batch_operation_commentaire_params
      params.require(:batch_operation).permit(:statut, dossier_ids: []).tap do |batch_params|
        batch_params[:operation] = 'create_commentaire'
        batch_params[:instructeur] = current_instructeur
        batch_params[:mark_as_pending_response] = params[:mark_as_pending_response] == 'true'
        batch_params.merge!(commentaire_params)
      end
    end

    def commentaire_params
      params.require(:commentaire).permit(
        :body,
        piece_jointe: []
      )
    end

    def set_procedure
      @procedure = Procedure.find(params[:procedure_id])
    end

    def ensure_ownership!
      if !current_instructeur.procedures.exists?(@procedure.id)
        flash[:alert] = "Vous n’avez pas accès à cette démarche"
        redirect_to root_path
      end
    end

    def render_redirect_and_close_modal
      render turbo_stream: turbo_stream.append(
        "contenu",
        partial: "shared/redirect_and_close_modal",
        locals: { redirect_url: instructeur_procedure_path(@procedure, statut: batch_operation_commentaire_params[:statut]) }
      )
    end

    def render_commentaire_form_with_errors(commentaire)
      @ids = submitted_dossier_ids

      render turbo_stream: turbo_stream.replace("modal-commentaire-batch-form",
        partial: "instructeurs/batch_operations/commentaire_form",
        locals: {
          url: create_batch_commentaire_instructeur_batch_operations_path(procedure_id: @procedure.id),
          commentaire: commentaire,
          procedure: @procedure,
          dossier_ids: @ids,
        })
    end
  end
end
