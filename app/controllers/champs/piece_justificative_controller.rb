# frozen_string_literal: true

class Champs::PieceJustificativeController < Champs::ChampController
  before_action :ensure_legitimate_access

  def show
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: root_url) }
    end
  end

  def update
    if attach_piece_justificative
      render :show
    else
      render json: { errors: @champ.errors.full_messages }, status: 422
    end
  end

  def template
    redirect_to rails_blob_url(@champ.type_de_champ.piece_justificative_template.blob, disposition: 'attachment')
  end

  private

  def ensure_legitimate_access
    return if @champ.piece_justificative? || @champ.quotient_familial?

    head :not_found
  end

  def attach_piece_justificative
    save_succeed = Attachment::PieceJustificativeService.attach_champ_pj(@champ, params[:blob_signed_id])

    if save_succeed
      @champ.fetch_later! if @champ.has_async_external_data? && @champ.may_fetch_later?

      @champ.update_timestamps

      dossier = DossierPreloader.load_one(@champ.dossier, pj_template: true)
      # because preloader reassigns new champ instances champs, we have to reassign it
      @champ = dossier.champs.find { it.id == @champ.id }
    end

    save_succeed
  end
end
