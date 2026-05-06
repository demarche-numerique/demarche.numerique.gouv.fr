# frozen_string_literal: true

class PrefillTypeDeChampsController < ApplicationController
  before_action :retrieve_procedure
  before_action :set_prefill_type_de_champ

  def show
  end

  private

  def retrieve_procedure
    @procedure = Procedure.publiees_ou_brouillons.opendata.find_with_path(params[:path]).first!
  end

  def set_prefill_type_de_champ
    type_de_champ = @procedure.active_revision.types_de_champ_public.filter(&:fillable?).find { _1.stable_id == params[:id].to_i }
    raise ActiveRecord::RecordNotFound if type_de_champ.blank?
    @type_de_champ = TypesDeChamp::PrefillTypeDeChamp.build(type_de_champ, @procedure.active_revision)
  end
end
