# frozen_string_literal: true

class ProceduresController < ApplicationController
  before_action :retrieve_procedure

  def logo
    if @procedure.logo.attached?
      logo_variant = @procedure.logo.variant(resize_to_limit: [400, 400])
      redirect_to url_for(logo_variant.image&.attached? ? logo_variant : @procedure.logo)
    else
      redirect_to ActionController::Base.helpers.image_url(PROCEDURE_DEFAULT_LOGO_SRC)
    end
  end

  private

  def retrieve_procedure
    @procedure = Procedure.find(params[:id])
  end
end
