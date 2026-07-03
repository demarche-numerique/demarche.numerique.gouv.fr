# frozen_string_literal: true

module Instructeurs
  class ChampsController < InstructeurController
    before_action :set_dossier
    before_action :set_dossier_stream
    before_action :set_rib_champ, only: [:edit]
    before_action :set_rib_champ_data_for_update, only: [:update]

    def edit
      render layout: "empty_layout"
    end

    def update
      rib = RIB.new(rib_params).to_h

      @rib_champ_data_for_update.update!(value_json: { rib:, hint: 'rib' })

      @dossier.merge_instructeur_buffer_stream!

      redirect_to instructeur_dossier_path(@dossier.procedure, @dossier), notice: t(".success", libelle: @rib_libelle)
    end

    private

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

    def set_rib_champ_data_for_update
      type_de_champ, row_id = find_rib_type_de_champ!
      @rib_libelle = type_de_champ.libelle
      @rib_champ_data_for_update = @dossier.champ_data_for_update(type_de_champ, row_id:, updated_by: current_instructeur.email)
    end

    def find_rib_type_de_champ!
      stable_id, row_id = params[:public_id].split("-")
      type_de_champ = @dossier.find_type_de_champ_by_stable_id(stable_id)
      raise ActiveRecord::RecordNotFound unless type_de_champ&.rib?
      [type_de_champ, row_id]
    end

    def rib_params = params.require(:rib).permit(:account_holder, :bank_name, :bic, :iban)
  end
end
