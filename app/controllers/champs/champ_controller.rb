# frozen_string_literal: true

class Champs::ChampController < ApplicationController
  before_action :authenticate_logged_user!
  before_action :set_champ

  private

  def find_champ
    dossier = policy_scope(Dossier).with_revision.includes(:champs).find(params[:dossier_id])
    scope = instructeur_signed_in? ? nil : :public
    type_de_champ = dossier.find_type_de_champ_by_stable_id(params[:stable_id], scope)

    if type_de_champ.nil? || !dossier_writable?(dossier, type_de_champ)
      head :not_found
      return
    end

    dossier.with_update_stream(current_user) if type_de_champ.public?

    if type_de_champ.repetition?
      DossierPreloader.load_one(dossier, pj_template: true)
      dossier.project_champ(type_de_champ)
    else
      dossier.champ_for_update(type_de_champ, row_id: params_row_id, updated_by: current_user.email)
    end
  end

  def dossier_writable?(dossier, type_de_champ)
    if type_de_champ.private?
      !dossier.brouillon?
    else
      dossier.brouillon? || dossier.en_construction?
    end
  end

  def params_row_id
    params[:row_id]
  end

  def set_champ
    @champ = find_champ
  end
end
