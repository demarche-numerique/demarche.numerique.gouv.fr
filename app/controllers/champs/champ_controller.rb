# frozen_string_literal: true

class Champs::ChampController < ApplicationController
  before_action :authenticate_logged_user!
  before_action :set_champ
  after_action :verify_authorized

  private

  def find_champ
    dossier = Dossier.with_revision.includes(:champ_data).find(params[:dossier_id])
    authorize dossier, :read?

    type_de_champ, row_id = dossier.find_type_de_champ_by_public_id!(champ_public_id_param)
    dossier.with_update_stream(current_user) if type_de_champ.public?
    @dossier = dossier

    if type_de_champ.repetition?
      DossierPreloader.load_one(dossier, pj_template: true)
      dossier.project_champ(type_de_champ)
    else
      dossier.with_champs if type_de_champ.public? && dossier.revision.parent_of(type_de_champ)&.min_repetitions?
      dossier.champ_for_update(type_de_champ, row_id:, updated_by: current_user.email)
    end
  end

  def set_champ
    @champ = find_champ
    authorize @champ, permission, policy_class:
  end

  def permission
    return :update_annotation? if @champ.private?
    :update?
  end
end
