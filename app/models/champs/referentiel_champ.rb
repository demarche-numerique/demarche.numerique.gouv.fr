# frozen_string_literal: true

class Champs::ReferentielChamp < ChampData
  delegate :referentiel,
           :referentiel_mapping_result_path,
           :referentiel_mapping_displayable,
           :referentiel_mapping_prefillable_with_stable_id,
           to: :type_de_champ

  delegate :exact_match?, :autocomplete?, to: :referentiel, allow_nil: true

  # Only a replaced identifier has a result to clear: the copy of a champ on a buffer sets it from nil.
  before_save :clear_previous_result, if: -> { external_id_changed? && external_id_was.present? }

  validate :validate_selection_readable

  def fetch_external_data
    # Les tags de l'URL sont résolus sur le stream du champ : sur un buffer, la ligne
    # de répétition en cours de saisie n'existe pas encore sur le stream principal.
    dossier.with_champ_stream(self) do
      ReferentielService.new(referentiel:).call(external_id, dossier:, row_id:)
    end.bind do |data|
      data = indifferent(data)
      if result_missing?(data)
        Failure(retryable: false, error: StandardError.new("Not found: nothing at #{result_path}"), code: 404)
      else
        Success({
          data:, # keep raw API response
          value: external_id, # now that we have the data, we can set the value
          value_json: cast_displayable_values(data), # columnize the data
        })
      end
    end
  end

  # Le chemin configuré sur le référentiel prime ; à défaut, celui que le mapping implique.
  def result_path
    referentiel.result_path.presence || referentiel_mapping_result_path
  end

  def update_external_data!(hash)
    dossier.with_champ_stream(self)

    transaction do
      super
      dossier.prefill_and_enqueue_fetch_external_data_jobs(self, prefillable_type_de_champs)
    end
  end

  def data=(data)
    if exact_match?
      super(data)
    elsif data.blank?
      # L'élément présélectionné de la combobox ne porte pas de jeton : resoumettre la valeur
      # courante ne doit pas effacer la donnée enregistrée, et une nouvelle valeur sans jeton
      # n'est pas une sélection.
      if value.blank?
        super(nil)
        # Pas de machine à états en autocomplétion : la proposition part là où la sélection l'a écrite.
        dossier.discard_instructeur_buffer_proposal!(public_prefill_type_de_champs) if private?
      elsif value_changed?
        reject_selection
      end
    else
      data = decrypt_selected_data(data)
      # Jeton illisible (altéré, mal formé) ou expiré : la sélection ne peut pas être
      # enregistrée. Celle déjà enregistrée reste, et l'usager est invité à refaire sa recherche.
      return reject_selection if data.nil?

      data = data.with_indifferent_access if data.is_a?(Hash)
      data = rewrap_selected_object_in_datasource(data)
      # Resélectionner la valeur courante (nouveau jeton, même donnée) ne réécrit rien et ne
      # relance pas le préremplissage, qui écraserait les champs modifiés depuis.
      return if data == self.data

      super(data)
      self.value_json = cast_displayable_values(data)

      dossier.prefill_and_enqueue_fetch_external_data_jobs(self, prefillable_type_de_champs)
    end
  end

  def has_async_external_data?
    exact_match?
  end

  # Une annotation qui préremplit le formulaire ne sert plus à rien quand le dossier ne peut
  # plus revenir à l'usager.
  def locked_prefill?
    private? && public_prefill_type_de_champs.any? && !dossier.may_receive_prefill_proposal?
  end

  # La proposition de l'ancienne référence part avec sa donnée, avant le nouvel appel.
  def after_reset_external_data(opts = {})
    super
    dossier.discard_instructeur_buffer_proposal!(public_prefill_type_de_champs) if private?
  end

  def prefillable_stable_ids
    @prefillable_stable_ids ||= referentiel_mapping_prefillable_with_stable_id
      .map { |_jsonpath, mapping| mapping[:prefill_stable_id].to_i }
  end

  def proposes_public_changes?
    private? && proposed_columns.any?
  end

  def proposed_columns
    stable_ids = public_prefill_type_de_champs.map(&:stable_id)
    dossier.instructeur_changed_columns.filter { it.stable_id.in?(stable_ids) }
  end

  def prefillable_champs
    elligible_stable_ids = prefillable_stable_ids
    if public?
      dossier.root_champs_public
    else
      dossier.root_champs_private
    end.filter do |champ|
      if champ.repetition?
        dossier.revision.children_of(champ.type_de_champ).any? { _1.stable_id.in?(elligible_stable_ids) }
      else
        champ.stable_id.in?(elligible_stable_ids)
      end
    end
  end

  def selected_key
    value
  end

  # Pas de `data` sur l'élément présélectionné : la combobox ne sait soumettre que le jeton
  # chiffré des suggestions, et resélectionner la valeur courante ne doit rien réécrire.
  def selected_items
    if selected_key.present?
      [{ label: selected_key, value: selected_key }]
    else
      []
    end
  end

  def propagate_prefill(type_de_champs)
    type_de_champs_by_stable_id = type_de_champs.index_by(&:stable_id)
    targets = referentiel_mapping_prefillable_with_stable_id
      .transform_values { type_de_champs_by_stable_id[it[:prefill_stable_id].to_i] }
      .compact

    public_targets, private_targets = targets.partition { |_, tdc| tdc.public? }.map(&:to_h)

    propagate_public_prefill(public_targets) + propagate_to(private_targets)
  end

  private

  # Une annotation écrit sur le buffer instructeur, où l'usager ne voit rien avant
  # que la proposition ne soit validée.
  def propagate_public_prefill(targets)
    return [] if targets.empty?
    return propagate_to(targets) if !private?

    dossier.discard_instructeur_buffer_proposal!(targets.values)
    dossier.with_instructeur_buffer_stream { propagate_to(targets) }
  end

  def public_prefill_type_de_champs
    prefillable_stable_ids.filter_map { dossier.find_type_de_champ_by_stable_id(it, :public) }
  end

  def propagate_to(targets)
    targets
      .group_by { |_, type_de_champ| dossier.revision.parent_of(type_de_champ) }
      .flat_map do |repetition_type_de_champ, mappings|
        if repetition_type_de_champ.nil?
          update_simple_prefillable_champs(data, mappings)
        elsif repetition_type_de_champ == parent
          prefill_own_row(data, mappings)
        else
          prefill_new_rows(data, repetition_type_de_champ, mappings)
        end
      end
  end

  def prefillable_type_de_champs
    if main_stream?
      dossier.revision.type_de_champs
    else
      dossier.public_type_de_champs_all
    end
  end

  def clear_previous_result
    self.value = nil
    self.data = nil
    self.value_json = nil
    self.fetch_external_data_exceptions = []
  end

  # Un jeton expiré est déchiffré en nil par Rails ; un jeton mal formé lève.
  def decrypt_selected_data(token)
    MessageEncryptorService.new.decrypt_and_verify(token, purpose: :storage)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  # `value` est assigné avant `data` (DossierEditConcern) : on le rétablit pour que le champ
  # soit ré-affiché avec la sélection enregistrée. L'erreur de validation empêche
  # l'enregistrement et s'affiche sous le champ.
  def reject_selection
    restore_attributes(['value'])
    @selection_rejected = true
  end

  def validate_selection_readable
    errors.add(:value, :unreadable_selection) if @selection_rejected
  end

  # Les API de liste (Grist, tabular-api, opendatasoft…) répondent 200 avec une collection
  # vide quand rien ne correspond à la référence saisie : la réponse ne compte comme trouvée
  # que si elle porte une valeur sous le chemin de résultat. false et 0 en sont une.
  def result_missing?(data)
    value = JSONPathUtil.on_safe(data, result_path).first
    value.nil? || value == '' || value == [] || value == {}
  end

  # API::Client symbolise les clés ; JSONPathUtil ne sait normaliser que celles d'un Hash.
  def indifferent(data)
    case data
    when Hash then data.with_indifferent_access
    when Array then data.map { indifferent(it) }
    else data
    end
  end

  def cast_display_value(type, value)
    case [type&.to_sym, value]
    in [:integer_number, v] if v.present?
      v.to_i
    in [:decimal_number, v] if v.present?
      v.to_f
    in [:datetime, v] if DateDetectionUtils.likely_string_timestamp?(v)
      timestamp = DateDetectionUtils.convert_unix_timestamp(v)
      return nil if timestamp.nil?
      Time.zone.at(timestamp).iso8601
    in [:datetime, v]
      DateDetectionUtils.convert_to_iso8601_datetime(v)
    in [:date, v] if DateDetectionUtils.likely_string_timestamp?(v)
      timestamp = DateDetectionUtils.convert_unix_timestamp(v)
      return nil if timestamp.nil?
      Time.zone.at(timestamp).to_date.iso8601
    in [:date, v]
      DateDetectionUtils.convert_to_iso8601_date(v)
    in [:boolean, v]
      ActiveModel::Type::Boolean.new.cast(v)
    in [:array, Array => arr] if ReferentielMappingUtils.array_of_supported_simple_types?(arr)
      Array(arr)
    in [:string, v] if !v.nil?
      v.to_s
    else
      nil
    end
  end

  def normalize_api_value(value, type_de_champ)
    case [type_de_champ.type_champ.to_sym, value]
    in [:drop_down_list, Array => arr] if ReferentielMappingUtils.array_of_supported_simple_types?(arr)
      arr.first.to_s
    else
      value
    end
  end

  def cast_displayable_values(json)
    referentiel_mapping_displayable.reduce({}) do |accu, (jsonpath, mapping)|
      json = json.first if json.is_a?(Array) # when json is an array, we take the first element
      casted_value = cast_display_value(mapping[:type], JSONPathUtil.on_safe(json, jsonpath).first)
      accu[jsonpath] = casted_value if !casted_value.nil?
      accu
    end
  end

  # In its own repetition, the champ writes on its own row: no row to add.
  # Note: limited to updating that row only.
  def prefill_own_row(data, mappings)
    group_mappings_by_json_array(mappings).flat_map do |array_key, array_mappings|
      json_elements(data, array_key).flat_map { prefill_row(element_attributes(it, array_mappings), row_id) }
    end
  end

  # Elsewhere (root champ, or a champ of another repetition), one new row per element.
  def prefill_new_rows(data, repetition_type_de_champ, mappings)
    group_mappings_by_json_array(mappings).flat_map do |array_key, array_mappings|
      json_elements(data, array_key)
        .map { element_attributes(it, array_mappings) }
        .flat_map { prefill_row(it, add_prefilled_row(repetition_type_de_champ)) }
    end
  end

  def group_mappings_by_json_array(mappings)
    mappings.group_by { |jsonpath, _| JSONPathUtil.extract_array_name(jsonpath) }
  end

  def json_elements(data, array_key)
    Array(JSONPathUtil.on_safe(data, array_key).first).compact_blank
  end

  def element_attributes(json_value, array_mappings)
    array_mappings.map do |jsonpath, type_de_champ|
      [type_de_champ, prefill_attributes_for(type_de_champ, raw_value_in(json_value, jsonpath))]
    end
  end

  def raw_value_in(json_value, jsonpath)
    if JSONPathUtil.json_path_contains_array?(jsonpath)
      JSONPathUtil.on_safe(json_value, JSONPathUtil.extract_key_after_array(jsonpath)).first
    else
      json_value
    end
  end

  def prefill_row(element_attributes, row_id)
    element_attributes.map { |type_de_champ, attributes| prefill_champ(type_de_champ, attributes, row_id:) }
  end

  # Reusing our own row_id would write a row of our repetition into another one, where no row
  # marker carries it: the data would be persisted but invisible to the whole app.
  def add_prefilled_row(repetition_type_de_champ)
    dossier.repetition_add_row(repetition_type_de_champ, updated_by:)
  end

  def update_simple_prefillable_champs(data, mappings)
    mappings.map do |jsonpath, type_de_champ|
      prefill_champ(type_de_champ, prefill_attributes_for(type_de_champ, JSONPathUtil.on_safe(data, jsonpath).first))
    end
  end

  # Screening reads only the dossier off the champ, so this champ stands in for the target.
  def prefill_attributes_for(type_de_champ, raw_value)
    TypesDeChamp::PrefillTypeDeChamp
      .build(type_de_champ, dossier.revision)
      .to_assignable_attributes(self, normalize_api_value(raw_value, type_de_champ))
  end

  def prefill_champ(type_de_champ, attributes, row_id: nil)
    champ = dossier.champ_for_update(type_de_champ, row_id:, updated_by:)
    return champ if attributes.nil?

    # A new identifier makes the fetched data stale: back to idle, so that the dossier fetches it again.
    champ.reset_external_data! if champ.has_async_external_data? && attributes.key?(:external_id) && champ.external_id != attributes[:external_id]
    champ.update(attributes.merge(prefilled: true, prefilled_original_value: attributes))
    champ
  end

  def rewrap_selected_object_in_datasource(data)
    full_jsonpath = type_de_champ.referentiel.datasource
    path_keys_separated_with_dot = full_jsonpath.split("$.")[1]
    if path_keys_separated_with_dot
      rewrap_to_hash(data, path_keys_separated_with_dot)
    else
      rewrap_to_array(data)
    end
  end

  def rewrap_to_hash(data, path_keys_separated_with_dot)
    path_keys = path_keys_separated_with_dot.split('.')
    reversed_keys_to_rebuild_datasource = path_keys.reverse

    # using reversed keys + reduce allows us to rebuild the original JSON structure
    reversed_keys_to_rebuild_datasource.reduce([data]) do |accumulator, key|
      { key => accumulator }
    end.with_indifferent_access
  end

  def rewrap_to_array(data)
    [data]
  end
end
