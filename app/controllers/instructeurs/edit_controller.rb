# frozen_string_literal: true

module Instructeurs
  class EditController < InstructeurController
    include TurboChampsConcern
    include DossierEditConcern

    attr_reader :dossier
    before_action :set_dossier
    before_action :reset_buffer, only: :show
    before_action :set_dossier_stream

    def show
      @demande_seen_at = current_instructeur.follows.find_by(dossier:)&.demande_seen_at

      render layout: "empty_layout"
    end

    def update
      update_champ_and_compute_errors(scope: :public)

      respond_to do |format|
        format.turbo_stream do
          @to_show, @to_hide, @to_update = champs_to_turbo_update(champs_attributes_params(:public), dossier.flat_champs_public)
          render layout: false
        end
      end
    end

    def validate
      dossier.champs_public_valid?

      @demande_seen_at = current_instructeur.follows.find_by(dossier:)&.demande_seen_at
      @can_confirm = dossier.errors.blank? && dossier.can_passer_en_construction?

      respond_to do |format|
        format.turbo_stream do
          render :validate, layout: false
        end
      end
    end

    def submit
      dossier.champs_public_valid?

      if dossier.errors.blank? && dossier.can_passer_en_construction?
        dossier.instructeur_submit_en_construction!(instructeur: current_instructeur, motivation: submit_params[:motivation])

        redirect_to instructeur_dossier_path(dossier.procedure, dossier, statut: params[:statut])
      else
        render :show, layout: "empty_layout"
      end
    end

    def champ
      type_de_champ = dossier.find_type_de_champ_by_stable_id!(params[:stable_id], :public, row_id: params[:row_id])
      champ = dossier.project_champ(type_de_champ, row_id: params[:row_id])
      champ.validate(:champ_value) if champ.done?

      respond_to do |format|
        format.turbo_stream do
          @to_show, @to_hide, @to_update = champ_to_turbo_update(champ, dossier.flat_champs_public)
          render :update, layout: false
        end
      end
    end

    private

    def set_dossier
      dossier = current_instructeur.dossiers.visible_by_administration.find(params[:dossier_id])
      @dossier = DossierPreloader.load_one(dossier)
    end

    def set_dossier_stream
      if dossier.can_update_as_instructeur?(current_user)
        dossier.with_instructeur_buffer_stream
        DossierPreloader.load_one(dossier)
      else
        redirect_to instructeur_dossier_path(dossier.procedure, dossier, statut: params[:statut])
      end
    end

    def reset_buffer
      dossier.reset_instructeur_buffer_stream!
    end

    def submit_params
      params.require(:traitement).permit(:motivation)
    end
  end
end
