# frozen_string_literal: true

class RootController < ApplicationController
  before_action :authenticate_administrateur!, only: :patron
  include ApplicationHelper

  def index
    if administrateur_signed_in?
      return redirect_to admin_procedures_path
    elsif instructeur_signed_in?
      return redirect_to instructeur_procedures_path
    elsif expert_signed_in?
      return redirect_to expert_all_avis_path
    elsif user_signed_in?
      return redirect_to dossiers_path
    elsif super_admin_signed_in?
      return redirect_to manager_root_path
    end

    @stat = Stat.first

    render 'landing'
  end

  def administration
  end

  def patron
    description = "Allez voir le super site : #{Current.application_base_url}"

    procedure = Procedure.create_with(for_individual: true,
        administrateurs: [current_administrateur],
        duree_conservation_dossiers_dans_ds: 1,
        max_duree_conservation_dossiers_dans_ds: Expired::DEFAULT_DOSSIER_RENTENTION_IN_MONTH,
        cadre_juridique: 'http://www.legifrance.gouv.fr',
        description:).find_or_initialize_by(libelle: 'Démarche de demo pour la page patron')

    if procedure.new_record?
      Procedure.transaction do
        procedure.draft_revision = procedure.revisions.build
        procedure.save!
        after_stable_id = nil
        TypeDeChamp.type_champs.values.sort.each do |type_champ|
          type_de_champ = procedure.draft_revision
            .add_type_de_champ(type_champ:, libelle: type_champ.humanize, description:, mandatory: true, private: false, after_stable_id:)
          after_stable_id = type_de_champ.stable_id

          if type_de_champ.repetition?
            repetition_after_stable_id = nil
            ['text', 'integer_number', 'checkbox'].each do |type_champ|
              repetition_type_de_champ = procedure.draft_revision
                .add_type_de_champ(type_champ:, libelle: type_champ.humanize, description:, mandatory: true, private: false, parent_stable_id: type_de_champ.stable_id, after_stable_id: repetition_after_stable_id)
              repetition_after_stable_id = repetition_type_de_champ.stable_id
            end
          elsif type_de_champ.linked_drop_down_list?
            type_de_champ.drop_down_options =
              [
                "-- section 1 --",
                "option A",
                "option B",
                "-- section 2 --",
                "option C",
              ]
            type_de_champ.save
          elsif type_de_champ.any_drop_down_list?
            type_de_champ.drop_down_options =
              [
                "option A",
                "option B",
                "-- avant l’option C --",
                "option C",
              ]
            type_de_champ.save
          elsif type_de_champ.referentiel?
            type_de_champ.referentiel = Referentiels::APIReferentiel.new(url: Referentiels::APIReferentiel.stub_url, mode: :autocomplete, name: SecureRandom.uuid, test_data: 'kkk')
            type_de_champ.save
          end
        end
      end
    end

    @dossier = procedure.draft_revision.dossier_for_preview(current_user)
  end

  def suivi
  end

  def save_locale
    set_locale(params[:locale])
    redirect_back(fallback_location: root_path)
  end
end
