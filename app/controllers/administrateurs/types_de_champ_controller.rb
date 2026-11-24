# frozen_string_literal: true

module Administrateurs
  class TypesDeChampController < AdministrateurController
    include ActiveSupport::NumberHelper
    include CsvParsingConcern

    before_action :retrieve_procedure

    include SimpliscoreConcern

    def create
      type_de_champ = draft.add_type_de_champ(type_de_champ_create_params)
      # not saved when refused: it holds why
      if type_de_champ.persisted?
        edited(type_de_champ)
        @created = champ_component_from(type_de_champ, focused: true)
        @morphed = champ_components_from(siblings_starting_at(type_de_champ, 1))
      else
        flash.alert = type_de_champ.errors.full_messages
      end
    end

    def update
      import_referentiel and return if referentiel_file.present?

      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])
      was_prefill_with_fc_information = type_de_champ.date? && type_de_champ.prefill_with_france_connect_information?
      update_params = type_de_champ_update_params(type_de_champ)

      if type_de_champ.type_champ_locked? && changing_of_type?(type_de_champ, update_params)
        refuse(type_de_champ, type_de_champ.type_change_locked_message)
      else
        referentiel_url_stable_ids = []

        if changing_of_type?(type_de_champ, update_params)
          referentiel_url_stable_ids = type_de_champ.stable_ids_used_in_referentiel_url
          type_de_champ = type_de_champ.becomes_type(update_params['type_champ'])
        end

        # the editor form can submit options of another type (type change, or a
        # stale tab autosaving after one): drop the ones the type does not define
        update_params = update_params.except(*update_params.keys.reject { type_de_champ.respond_to?("#{it}=") })

        if draft.update_type_de_champ(type_de_champ, update_params)
          # as the draft lays it out by now, of another type or not
          type_de_champ = draft.type_de_champ(params[:stable_id])
          edited(type_de_champ)
          @morphed = if was_prefill_with_fc_information != (type_de_champ.date? && type_de_champ.prefill_with_france_connect_information?)
            champ_components_from(draft.type_de_champs)
          else
            champ_components_from(type_de_champs_for(referentiel_url_stable_ids) + siblings_starting_at(type_de_champ))
          end
        else
          # as the draft has it: the one that failed to save may be of another type
          edited(draft.type_de_champ(params[:stable_id]))
          flash.alert = type_de_champ.errors.full_messages
        end
      end
    end

    def piece_justificative_template
      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])

      if type_de_champ.piece_justificative_template.attach(params[:blob_signed_id])
        edited(type_de_champ)
        @morphed = [champ_component_from(type_de_champ)]

        render :create
      else
        render json: { errors: type_de_champ.errors.full_messages }, status: 422
      end
    end

    def notice_explicative
      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])

      if type_de_champ.notice_explicative.attach(params[:blob_signed_id])
        edited(type_de_champ)
        @morphed = [champ_component_from(type_de_champ)]

        render :create
      else
        render json: { errors: type_de_champ.errors.full_messages }, status: 422
      end
    end

    def move_and_morph
      from = draft.type_de_champ(params[:stable_id])&.then { it.flat_siblings.index(it) }
      type_de_champ = draft.move_type_de_champ_after(params[:stable_id], params[:target_stable_id])
      # nil in case of replay (champ removed in another tab)
      return if type_de_champ.nil?

      edited(type_de_champ)
      @destroyed = type_de_champ
      @created = champ_component_from(type_de_champ)
      to = @siblings.index(type_de_champ)
      # what sits between where it was and where it is by now
      @morphed = champ_components_from(from > to ? @siblings[to..from] : @siblings[from...to])
    end

    def move_up
      type_de_champ = draft.move_up_type_de_champ(params[:stable_id])
      # nil in case of replay (champ removed in another tab)
      return if type_de_champ.nil?

      edited(type_de_champ)
      @destroyed = type_de_champ
      @created = champ_component_from(type_de_champ)
      # update the one component below
      @morphed = champ_components_from(siblings_starting_at(type_de_champ, 1).take(1))
    end

    def move_down
      type_de_champ = draft.move_down_type_de_champ(params[:stable_id])
      # nil in case of replay (champ removed in another tab)
      return if type_de_champ.nil?

      edited(type_de_champ)
      @destroyed = type_de_champ
      @created = champ_component_from(type_de_champ)
      # update the one component above
      @morphed = champ_components_from(siblings_starting_at(type_de_champ, - 1).take(1))
    end

    def destroy
      type_de_champ = draft.type_de_champ(params[:stable_id])

      if type_de_champ&.type_champ_locked?
        refuse(type_de_champ, type_de_champ.deletion_locked_message)
      elsif type_de_champ.present?
        index = type_de_champ.flat_siblings.index(type_de_champ)
        referentiel_url_stable_ids = type_de_champ.stable_ids_used_in_referentiel_url
        # nil in case of replay (double click, champ already removed)
        if draft.remove_type_de_champ(params[:stable_id]).present?
          edited(type_de_champ)
          @destroyed = type_de_champ
          # the ones that followed it
          @morphed = champ_components_from(type_de_champs_for(referentiel_url_stable_ids) + @siblings.drop(index))
        end
      end
    end

    def nullify_referentiel
      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])
      type_de_champ.update!(referentiel_id: nil)

      edited(type_de_champ)
      @morphed = champ_components_from(siblings_starting_at(type_de_champ))
    end

    def import_referentiel
      case validate_csv_upload(referentiel_file)
      when :not_csv
        return flash[:alert] = "Importation impossible : veuillez importer un fichier CSV"
      when :too_large
        return flash[:alert] = "Importation impossible : le poids du fichier est supérieur à #{number_to_human_size(CSV_MAX_SIZE)}"
      end

      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])
      csv_content = parse_csv(referentiel_file, keep_original_headers: true)

      return flash[:alert] = "Importation impossible : le fichier est vide ou mal interprété" if csv_content.empty?
      return flash[:alert] = "Importation impossible : votre fichier CSV fait plus de #{helpers.number_with_delimiter(CSV_MAX_LINES)} lignes" if csv_content.size > CSV_MAX_LINES

      headers = csv_content.first.keys
      digest = Digest::SHA256.hexdigest(csv_content.to_json)

      ActiveRecord::Base.transaction do
        referentiel = type_de_champ.create_referentiel!(
          name: referentiel_file.original_filename,
          headers: headers,
          type: 'Referentiels::CsvReferentiel',
          digest: digest
        )

        items_to_insert = csv_content.map do |row|
          normalized_row = row.transform_values { ValueNormalizer.normalize(_1) }

          {
            data: { row: normalized_row.transform_keys { Referentiel.header_to_path(_1) } },
            referentiel_id: referentiel.id,
          }
        end

        ReferentielItem.insert_all(items_to_insert)
      end

      edited(type_de_champ)
      @morphed = champ_components_from(siblings_starting_at(type_de_champ))
    end

    private

    def changing_of_type?(type_de_champ, update_params)
      update_params['type_champ'].present? && update_params['type_champ'] != type_de_champ.type_champ
    end

    # Where the edit took place, for what the stream refreshes around it. Read
    # off the draft as it is by now: a type de champ removed holds the layout
    # it had.
    def edited(type_de_champ)
      @private = type_de_champ.private?
      @repetition = draft.type_de_champ(type_de_champ.enclosing_repetition.stable_id) if type_de_champ.in_repetition?
      @siblings = if @repetition
        @repetition.flat_children
      elsif @private
        draft.private_root_type_de_champs
      else
        draft.public_root_type_de_champs
      end
    end

    # the champ is left as it is, and shows why
    def refuse(type_de_champ, errors)
      edited(type_de_champ)
      @morphed = [champ_component_from(type_de_champ, errors:)]
      flash.alert = errors
    end

    def siblings_starting_at(type_de_champ, offset = 0)
      @siblings.drop([@siblings.index(type_de_champ) + offset, 0].max)
    end

    def type_de_champs_for(stable_ids)
      stable_ids.filter_map { draft.type_de_champ(it) }
    end

    def champ_component_from(type_de_champ, focused: false, errors: '')
      champ_components_from([type_de_champ], focused:, errors:).first
    end

    # a repetition shows the files of what it holds
    def champ_components_from(type_de_champs, focused: false, errors: '')
      TypeDeChamp.preload_attachments(type_de_champs.flat_map { [it, *it.flat_children] })

      type_de_champs.map { TypesDeChampEditor::NodeComponent.new(type_de_champ: it, focused:, errors:) }
    end

    def type_de_champ_create_params
      params
        .required(:type_de_champ)
        .permit(:type_champ, :parent_stable_id, :private, :libelle, :after_stable_id)
    end

    def type_de_champ_update_params(type_de_champ)
      permitted = params.required(:type_de_champ).permit(:type_champ,
        :numeric_type_champ,
        :libelle,
        :description,
        :mandatory,
        :pj_limit_formats,
        :pj_auto_purge,
        { pj_format_families: [] },
        :drop_down_options_from_text,
        :drop_down_other,
        :pre_rempli_hidden,
        :drop_down_secondary_libelle,
        :drop_down_secondary_description,
        :drop_down_mode,
        :collapsible_explanation_enabled,
        :collapsible_explanation_text,
        :header_section_level,
        :positive_number,
        :min_number,
        :max_number,
        :range_number,
        :birthdate,
        :limit_repetitions,
        :min_repetitions,
        :max_repetitions,
        :prefill_with_france_connect_information,
        :date_in_past,
        :range_date,
        :start_date,
        :end_date,
        :character_limit,
        :formatted_mode,
        :numbers_accepted,
        :letters_accepted,
        :special_characters_accepted,
        :min_character_length,
        :max_character_length,
        :expression_reguliere,
        :expression_reguliere_indications,
        :expression_reguliere_exemple_text,
        :expression_reguliere_error_message,
        :nature,
        :procedures_limit,
        dossier_link_procedure_ids: [],
        editable_options: [
          :cadastres,
          :rpg,
          :unesco,
          :arretes_protection,
          :conservatoire_littoral,
          :reserves_chasse_faune_sauvage,
          :reserves_biologiques,
          :reserves_naturelles,
          :natura_2000,
          :zones_humides,
          :znieff,
        ])
      permitted[:type_champ] = resolved_type_champ(permitted[:type_champ], type_de_champ) if permitted.key?(:type_champ)
      permitted
    end

    def resolved_type_champ(type_champ, type_de_champ)
      return type_champ if type_champ != TypeDeChamp::NUMERIC_MENU_VALUE

      toggle_type_champ = params.dig(:type_de_champ, :numeric_type_champ)
      already_numeric = type_de_champ.is_a?(TypesDeChamp::NumericTypeDeChamp)
      toggle_locked = already_numeric && toggle_type_champ.nil?

      return type_de_champ.type_champ if toggle_locked
      return toggle_type_champ if TypeDeChamp.numeric_type_champ?(toggle_type_champ)

      'integer_number'
    end

    def draft
      @procedure.draft_revision
    end

    def referentiel_file
      params["referentiel_file"]
    end
  end
end
