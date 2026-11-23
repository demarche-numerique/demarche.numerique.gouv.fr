# frozen_string_literal: true

module Administrateurs
  class TypesDeChampController < AdministrateurController
    include ActiveSupport::NumberHelper
    include ActionView::RecordIdentifier
    include CsvParsingConcern

    before_action :retrieve_procedure

    include SimpliscoreConcern

    # A request the editor of another tab made impossible: the place a type de
    # champ was to take is gone. The page shows the form as it is.
    rescue_from TypeDeChampTree::EditError do
      render turbo_stream: turbo_stream.refresh
    end

    def create
      editing do
        type_de_champ = draft.add_type_de_champ(type_de_champ_create_params)

        if type_de_champ.errors.empty?
          @focused = type_de_champ
          edited(type_de_champ)
        else
          flash.alert = type_de_champ.errors.full_messages
        end
      end
    end

    def update
      if referentiel_file.present?
        import_referentiel
        return render_edited
      end

      editing do
        type_de_champ = draft.type_de_champ(params[:stable_id]) || raise(ActiveRecord::RecordNotFound)
        was_prefill_with_fc_information = prefill_with_fc_information?(type_de_champ)
        type_champ_was = type_de_champ.type_champ
        referentiel_url_stable_ids = type_de_champ.stable_ids_used_in_referentiel_url
        type_de_champ = draft.update_type_de_champ(params[:stable_id], type_de_champ_update_params(type_de_champ))

        if type_de_champ.errors.empty?
          # every date tells whether another one is prefilled
          touched = was_prefill_with_fc_information != prefill_with_fc_information?(type_de_champ) ? draft.type_de_champs.filter(&:date?) : []
          # what the url of its reference dataset read is unlocked by a type change
          touched |= type_de_champs_for(referentiel_url_stable_ids) if type_de_champ.type_champ != type_champ_was
          edited(type_de_champ, touched: touched | self_and_following(type_de_champ))
        else
          flash.alert = type_de_champ.errors.full_messages
          # as the draft has it: the one that failed to save may be of another type
          type_de_champ = draft.type_de_champ(params[:stable_id])
          edited(type_de_champ, touched: [type_de_champ])
        end
      end
    end

    def piece_justificative_template
      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])

      if type_de_champ.piece_justificative_template.attach(params[:blob_signed_id])
        edited(type_de_champ, touched: [type_de_champ])

        render_edited
      else
        render json: { errors: type_de_champ.errors.full_messages }, status: 422
      end
    end

    def notice_explicative
      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])

      if type_de_champ.notice_explicative.attach(params[:blob_signed_id])
        edited(type_de_champ, touched: [type_de_champ])

        render_edited
      else
        render json: { errors: type_de_champ.errors.full_messages }, status: 422
      end
    end

    # To a place of its block: first of it ("first"), first of one of its header
    # sections ("first:<stable id>"), or after another type de champ
    # ("after:<stable id>").
    def move
      where, target_stable_id = params.require(:place).split(':')

      move_with(:move) do |stable_id|
        case where
        when 'after' then draft.move_type_de_champ(stable_id, after_stable_id: target_stable_id)
        when 'first' then draft.move_type_de_champ(stable_id, parent_stable_id: target_stable_id || draft.type_de_champ(stable_id)&.enclosing_repetition&.stable_id)
        else raise ActionController::BadRequest
        end
      end
    end

    def move_up = move_with(:move_up) { draft.move_up_type_de_champ(it) }
    def move_down = move_with(:move_down) { draft.move_down_type_de_champ(it) }
    def move_in = move_with(:move_in) { draft.move_in_type_de_champ(it) }
    def move_out = move_with(:move_out) { draft.move_out_type_de_champ(it) }
    def take_following_siblings = move_with(:take_following_siblings) { draft.take_following_siblings(it) }

    def destroy
      editing do
        # what the url of its reference dataset read is unlocked
        referentiel_url_stable_ids = draft.type_de_champ(params[:stable_id])&.stable_ids_used_in_referentiel_url || []
        edited(draft.remove_type_de_champ(params[:stable_id]), touched: type_de_champs_for(referentiel_url_stable_ids))
      end
    end

    def nullify_referentiel
      type_de_champ = draft.find_and_ensure_exclusive_use(params[:stable_id])
      type_de_champ.update!(referentiel_id: nil)

      edited(type_de_champ, touched: self_and_following(type_de_champ))
      render_edited
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

      edited(type_de_champ, touched: self_and_following(type_de_champ))
    end

    private

    # Runs an edit of the draft and renders what it changes on the page: the
    # blocks are read before it, to tell. A refused edit leaves the form as it
    # is, and says why on the type de champ it was about.
    def editing
      @blocks_before = draft.type_de_champs.group_by { block_key(it) }.transform_values { TypesDeChampEditor::BlockChanges::Snapshot.of(it) }

      begin
        yield
      rescue RevisionEditConcern::RefusedError => e
        flash.alert = e.message
        type_de_champ = draft.type_de_champ(params[:stable_id])

        if type_de_champ
          @errors = { type_de_champ.stable_id => e.message }
          edited(type_de_champ, touched: [type_de_champ])
        end
      end

      render_edited
    end

    # every edit answers with the same stream
    def render_edited
      respond_to { |format| format.turbo_stream { render :edited } }
    end

    # The list item of the one moved is taken out and rendered again where it
    # sits by now: what the others hold of unsaved input stays. Its card gets
    # the focus back, on the button which moved it if it is still there.
    def move_with(move)
      editing do
        type_de_champ = yield params[:stable_id]

        edited(type_de_champ, touched: [type_de_champ])
        @focused_control = TypesDeChampEditor::ChampComponent.new(type_de_champ:).focus_after(move)
      end
    end

    # Where the edit took place: its block, as the draft lays it out by now,
    # for what the stream brings up to date. A type de champ removed tells
    # where it sat.
    #
    # touched: the types de champ to show again as they are, wherever they sit.
    def edited(type_de_champ, touched: [])
      @private = type_de_champ.private?
      @repetition = draft.type_de_champ(type_de_champ.enclosing_repetition.stable_id) if type_de_champ.in_repetition?
      @type_de_champs = if @repetition
        @repetition.flat_children
      elsif @private
        draft.private_root_type_de_champs
      else
        draft.public_root_type_de_champs
      end

      after = TypesDeChampEditor::BlockChanges::Snapshot.of(@type_de_champs)
      # no block read before: an edit which leaves every type de champ in its place
      before = @blocks_before ? @blocks_before.fetch(block_key(type_de_champ)) { TypesDeChampEditor::BlockChanges::Snapshot.of([]) } : after
      @changes = TypesDeChampEditor::BlockChanges.new(before:, after:, touched: touched.map(&:stable_id))
      # what a repetition holds reads what comes before the repetition: shown
      # again with its card, but for an edit of the repetition itself
      held = @changes.cards.map { draft.type_de_champ(it) }.filter { it.repetition? && it.stable_id != type_de_champ.stable_id }.flat_map(&:flat_children)
      @touched_elsewhere = touched.reject { after.include?(it.stable_id) } | held

      # a repetition shows the files of what it holds
      TypeDeChamp.preload_attachments([*@type_de_champs.flat_map { it.repetition? ? [it, *it.flat_children] : [it] }, *@touched_elsewhere])
    end

    def type_de_champs_for(stable_ids)
      stable_ids.filter_map { draft.type_de_champ(it) }
    end

    def block_key(type_de_champ)
      [type_de_champ.private?, type_de_champ.enclosing_repetition&.stable_id]
    end

    # itself and what comes after it in its block: what may read it in a condition
    def self_and_following(type_de_champ)
      type_de_champ.flat_siblings.drop_while { it.stable_id != type_de_champ.stable_id }
    end

    def prefill_with_fc_information?(type_de_champ)
      type_de_champ.date? && type_de_champ.prefill_with_france_connect_information?
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
