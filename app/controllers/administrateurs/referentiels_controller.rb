# frozen_string_literal: true

module Administrateurs
  class ReferentielsController < AdministrateurController
    before_action :retrieve_procedure
    before_action :retrieve_type_de_champ
    before_action :retrieve_referentiel, except: [:new, :create]
    before_action :reachable_referentiel?, only: [:mapping_type_de_champ, :autocomplete_configuration]
    layout 'empty_layout'

    def new
      @referentiel = @type_de_champ.build_referentiel(build_or_clone_by_id_params)
    end

    def configuration_error
    end

    def edit
      render :new
    end

    def create
      handle_referentiel_save(@type_de_champ.build_referentiel(referentiel_params))
    end

    def update
      @referentiel.assign_attributes(referentiel_params)
      handle_referentiel_save(@referentiel)
    end

    def update_autocomplete_configuration
      if @referentiel.update(autocomplete_configuration_params) && params[:commit].present?
        redirect_to mapping_type_de_champ_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel), flash: { notice: "La configuration de l’autocomplete a bien été enregistrée" }
      else
        @referentiel.validate
        component = Referentiels::AutocompleteConfigurationComponent.new(referentiel: @referentiel, type_de_champ: @type_de_champ, procedure: @procedure)
        render turbo_stream: turbo_stream.replace(component.id, component)
      end
    end

    def autocomplete_configuration
    end

    def mapping_type_de_champ
    end

    def update_mapping_type_de_champ
      if @type_de_champ.update(referentiel_mapping: @type_de_champ.safe_referentiel_mapping.deep_merge(referentiel_mapping_params))
        redirect_to prefill_and_display_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel), flash: { notice: "La configuration du mapping a bien été enregistrée" }
      else
        redirect_to mapping_type_de_champ_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel), flash: { alert: "Une erreur est survenue" }
      end
    end

    def update_prefill_and_display_type_de_champ
      if @type_de_champ.update(referentiel_mapping: @type_de_champ.safe_referentiel_mapping.deep_merge(referentiel_mapping_params))
        if @type_de_champ.public?
          redirect_to champs_admin_procedure_path(@procedure), flash: { notice: "La configuration du pré remplissage des champs et/ou affichage des données récupérées a bien été enregistrée" }
        else
          redirect_to annotations_admin_procedure_path(@procedure), flash: { notice: "La configuration du pré remplissage des champs et/ou affichage des données récupérées a bien été enregistrée" }
        end
      else
        redirect_to prefill_and_display_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel), flash: { alert: "Une erreur est survenue" }
      end
    end

    private

    def reachable_referentiel?
      if !ReferentielService.new(referentiel: @referentiel).validate_referentiel
        redirect_to configuration_error_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel), flash: { alert: "Le référentiel n’est pas accessible" }
      end
    end

    def handle_referentiel_save(referentiel)
      url_changed = referentiel.url_changed?
      auto_submitted = params[:commit].blank?
      saved = referentiel.configured? && referentiel.save

      if saved && url_changed # cache bust
        @type_de_champ.update!(referentiel_mapping: {})
        referentiel.update!(last_response: nil, autocomplete_configuration: {})
      end

      if !auto_submitted
        referentiel.validate
      elsif url_changed
        referentiel.url_allowed?
      end

      if saved && !auto_submitted
        if referentiel.autocomplete?
          redirect_to autocomplete_configuration_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, referentiel)
        else
          redirect_to mapping_type_de_champ_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, referentiel)
        end
      else
        component = Referentiels::NewFormComponent.new(referentiel:, type_de_champ: @type_de_champ, procedure: @procedure)
        render turbo_stream: turbo_stream.replace(component.id, component)
      end
    end

    def referentiel_mapping_params
      permitted_mapping = {}

      params.require(:type_de_champ)
        .require(:referentiel_mapping)
        .each do |jsonpath_key, attributes|
          permitted_mapping[Referentiels::MappingFormBase.simili_to_jsonpath(jsonpath_key)] = attributes.permit(:type, :prefill_stable_id, :example_value, :libelle, :prefill, :display_instructeur, :display_usager).to_h
        end
      permitted_mapping
    end

    def referentiel_params
      params.require(:referentiel)
        .permit(:type, :mode, :url, :hint, :test_data, :authentication_method, authentication_data: [:header, :value])
    rescue ActionController::ParameterMissing
      {}
    end

    def retrieve_type_de_champ
      @type_de_champ = @procedure.draft_revision.find_and_ensure_exclusive_use(params[:stable_id])
    end

    def retrieve_referentiel
      @referentiel = Referentiel.find(params[:id])
    end

    def build_or_clone_by_id_params
      if params[:referentiel_id]
        Referentiel.find(params[:referentiel_id]).attributes.slice(*%w[url test_data hint mode type authentication_data authentication_method])
      else
        params = referentiel_params.to_h
        params = params.merge(type: Referentiels::APIReferentiel) if !Referentiels::APIReferentiel.csv_available?
        params
      end
    end

    def autocomplete_configuration_params
      params.require(:referentiel)
        .permit(:datasource, :tiptap_template)
    rescue ActionController::ParameterMissing
      {}
    end
  end
end
