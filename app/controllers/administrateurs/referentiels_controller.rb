# frozen_string_literal: true

module Administrateurs
  class ReferentielsController < AdministrateurController
    before_action :retrieve_procedure
    before_action :retrieve_type_de_champ
    before_action :retrieve_referentiel, except: [:new, :create, :validate_url]
    before_action :ensure_exclusive_referentiel, only: [:update, :update_autocomplete_configuration]
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
      handle_referentiel_save(@type_de_champ.build_referentiel(referentiel_params_with_carried_attributes))
    end

    def update
      @referentiel.assign_attributes(referentiel_params)
      handle_referentiel_save(@referentiel)
    end

    def validate_url
      @referentiel = Referentiels::APIReferentiel.new(referentiel_params.slice(:url_tiptap, :test_data_tiptap))
      @referentiel.url_allowed?

      render turbo_stream: [
        turbo_stream.replace(
          'url-validation-feedback',
          partial: 'administrateurs/referentiels/url_validation_feedback',
          locals: { referentiel: @referentiel }
        ),
        turbo_stream.replace(
          'test-data-fields',
          partial: 'administrateurs/referentiels/test_data_fields',
          locals: { referentiel: @referentiel, test_data_tags: @referentiel.test_data_tags }
        ),
      ]
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

    def reset_mapping
      scope = params[:scope]
      raise ActionController::BadRequest unless RESET_MAPPING_KEYS.key?(scope)

      if scope == 'all'
        @type_de_champ.update!(referentiel_mapping: {})
      else
        cleaned = @type_de_champ.safe_referentiel_mapping.transform_values { it.except(*RESET_MAPPING_KEYS[scope]) }
        @type_de_champ.update!(referentiel_mapping: cleaned)
      end

      redirect_back_or_to mapping_type_de_champ_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel),
                         flash: { notice: "La configuration a bien été réinitialisée" }
    end

    private

    RESET_MAPPING_KEYS = {
      'all' => nil,
      'display' => [:display_instructeur, :display_usager],
      'prefill' => [:prefill, :prefill_stable_id],
    }.freeze

    def reachable_referentiel?
      if !ReferentielService.new(referentiel: @referentiel).validate_referentiel
        redirect_to configuration_error_admin_procedure_referentiel_path(@procedure, @type_de_champ.stable_id, @referentiel), flash: { alert: "Le référentiel n’est pas accessible" }
      end
    end

    def handle_referentiel_save(referentiel)
      url_changed = referentiel.url_tiptap_changed?
      auto_submitted = params[:commit].blank?
      saved = referentiel.configured? && referentiel.save

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
        .permit(:type, :mode, :hint, :url_tiptap,
                :authentication_method, authentication_data: [:header, :value],
                test_data_tiptap: {})
    rescue ActionController::ParameterMissing
      {}
    end

    # When cloning an existing referentiel, some attributes are not submitted by the
    # form and would be lost on save: the auth inputs are rendered as `disabled` to
    # hide the secret, and the autocomplete configuration belongs to a later step of
    # the wizard. We carry them over from the source.
    def referentiel_params_with_carried_attributes
      attrs = referentiel_params.to_h
      source_id = params.dig(:referentiel, :referentiel_id).presence
      return attrs if source_id.blank?

      source = @type_de_champ.referentiel
      return attrs if source.nil? || source.id != source_id.to_i

      if attrs[:authentication_method] == 'header_token' && attrs[:authentication_data].blank?
        attrs[:authentication_data] = source.authentication_data
      end
      attrs[:autocomplete_configuration] = source.autocomplete_configuration if source.autocomplete_configuration.present?
      attrs
    end

    def retrieve_type_de_champ
      @type_de_champ = @procedure.draft_revision.find_and_ensure_exclusive_use(params[:stable_id])
    end

    # L'id de l'URL doit être celui du référentiel courant du champ. Après une duplication
    # (ensure_exclusive_referentiel), une requête encore en vol qui porte l'ancien id
    # obtient un 404 plutôt que d'écrire sur le référentiel de la révision publiée.
    def retrieve_referentiel
      @referentiel = @type_de_champ.referentiel
      raise ActiveRecord::RecordNotFound if @referentiel.nil? || @referentiel.id != params[:id].to_i
    end

    # Le champ du brouillon est déjà exclusif (retrieve_type_de_champ) ; son référentiel
    # doit l'être aussi avant d'être modifié, sinon la révision publiée le verrait changer.
    def ensure_exclusive_referentiel
      @referentiel = @type_de_champ.ensure_exclusive_referentiel!
    end

    def build_or_clone_by_id_params
      if params[:referentiel_id]
        referentiel = @type_de_champ.referentiel
        raise ActiveRecord::RecordNotFound if referentiel.nil? || referentiel.id != params[:referentiel_id].to_i
        referentiel.attributes.slice(*%w[url_tiptap test_data_tiptap hint mode type authentication_data authentication_method])
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
