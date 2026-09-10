# frozen_string_literal: true

module Instructeurs
  class ChampsController < InstructeurController
    STREAM_UNIQUE_INDEX = 'index_champs_on_stream_and_public_id'

    before_action :set_dossier
    before_action :set_dossier_stream
    before_action :set_rib_champ, only: [:edit]
    before_action :set_rib_champ_for_update, only: [:update]

    def edit
      render layout: "empty_layout"
    end

    def update
      rib = RIB.new(rib_params).to_h

      @rib_champ_for_update.update!(value_json: { rib:, hint: 'rib' })

      merge_instructeur_buffer_stream

      redirect_to instructeur_dossier_path(@dossier.procedure, @dossier), notice: t(".success", libelle: @rib_champ_for_update.libelle)
    end

    private

    # A merge names its history stream after the current second, so a form
    # submitted twice inside that second trips the unique index on the second
    # merge. The client keeps the form locked until the redirect renders; if a
    # duplicate still gets through, the first save already holds these values
    # and the pending copy is folded into the next checkpoint. It is still
    # reported: it should not happen, and anything else hitting that index
    # must keep raising.
    def merge_instructeur_buffer_stream
      @dossier.merge_instructeur_buffer_stream!
    rescue ActiveRecord::RecordNotUnique => e
      raise unless violated_constraint(e) == STREAM_UNIQUE_INDEX

      Sentry.capture_exception(
        e,
        level: :warning,
        fingerprint: ['rib_update_duplicate_merge'],
        extra: { dossier: @dossier.id, public_id: params[:public_id] }
      )
    end

    def violated_constraint(error)
      error.cause.try(:result)&.error_field(PG::PG_DIAG_CONSTRAINT_NAME)
    end

    def set_dossier
      @dossier = DossierPreloader.load_one(
        current_instructeur.dossiers.visible_by_administration.find(params[:dossier_id])
      )
    end

    def set_dossier_stream
      @dossier.with_instructeur_buffer_stream
    end

    def set_rib_champ
      type_de_champ, row_id = find_rib_type_de_champ!
      @rib_champ = @dossier.project_champ(type_de_champ, row_id:)
    end

    def set_rib_champ_for_update
      type_de_champ, row_id = find_rib_type_de_champ!
      @rib_champ_for_update = @dossier.champ_for_update(type_de_champ, row_id:, updated_by: current_instructeur.email)
    end

    def find_rib_type_de_champ!
      stable_id, row_id = params[:public_id].split("-")
      type_de_champ = @dossier.find_type_de_champ_by_stable_id(stable_id)
      raise ActiveRecord::RecordNotFound if !(type_de_champ&.piece_justificative? && type_de_champ.rib?)
      [type_de_champ, row_id]
    end

    def rib_params = params.require(:rib).permit(:account_holder, :bank_name, :bic, :iban)
  end
end
