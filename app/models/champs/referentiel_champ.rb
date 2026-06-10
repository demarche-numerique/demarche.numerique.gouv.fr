# frozen_string_literal: true

class Champs::ReferentielChamp < Champ
  delegate :referentiel,
           :referentiel_mapping_displayable,
           :referentiel_mapping_prefillable_with_stable_id,
           to: :type_de_champ

  delegate :exact_match?, :autocomplete?, to: :referentiel, allow_nil: true

  before_save :clear_previous_result, if: -> { external_id_changed? }

  def fetch_external_data
    ReferentielService.new(referentiel:).call(external_id, dossier:).fmap do |data|
      {
        data:, # keep raw API response
        value: external_id, # now that we have the data, we can set the value
        value_json: cast_displayable_values(data.with_indifferent_access), # columnize the data
      }
    end
  end

  def update_external_data!(hash)
    dossier.with_champ_stream(self)

    transaction do
      update!(hash.merge(fetch_external_data_exceptions: [])) # void previous errors
      dossier.prefill_and_enqueue_fetch_external_data_jobs(self, prefillable_types_de_champ)
    end
  end

  def data=(data)
    if exact_match? || data.blank?
      super(data)
    else
      message_encryptor_service = MessageEncryptorService.new
      data = message_encryptor_service.decrypt_and_verify(data, purpose: :storage)
      data = data.with_indifferent_access if data.is_a?(Hash)
      data = rewrap_selected_object_in_datasource(data)

      super(data)
      self.value_json = cast_displayable_values(data)

      dossier.prefill_and_enqueue_fetch_external_data_jobs(self, prefillable_types_de_champ)
    end
  end

  def has_async_external_data?
    exact_match?
  end

  def prefillable_stable_ids
    @prefillable_stable_ids ||= referentiel_mapping_prefillable_with_stable_id
      .map { |_jsonpath, mapping| mapping[:prefill_stable_id].to_i }
  end

  def prefillable_champs
    elligible_stable_ids = prefillable_stable_ids
    if public?
      dossier.project_champs_public
    else
      dossier.project_champs_private
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

  def selected_items
    if selected_key.present?
      [{ label: selected_key, value: selected_key, data: value_json }]
    else
      []
    end
  end

  def propagate_prefill(types_de_champ)
    types_de_champ_by_stable_id = types_de_champ.index_by(&:stable_id)
    referentiel_mapping_prefillable_with_stable_id
      .transform_values do |mapping|
        types_de_champ_by_stable_id[mapping[:prefill_stable_id].to_i]
      end.compact.group_by do |_, type_de_champ|
        dossier.revision.parent_of(type_de_champ)
      end.flat_map do |repetition_type_de_champ, mappings|
        if repetition_type_de_champ.present?
          update_repetition_prefillable_champs(data, repetition_type_de_champ, mappings)
        else
          update_simple_prefillable_champs(data, mappings)
        end
      end
  end

  private

  def prefillable_types_de_champ
    if stream == Champ::MAIN_STREAM
      dossier.revision.types_de_champ
    else
      dossier.types_de_champ_public_all
    end
  end

  def clear_previous_result
    self.value = nil
    self.data = nil
    self.value_json = nil
    self.fetch_external_data_exceptions = []
  end

  def call_caster(mapping_or_type_champ, value, type_de_champ = nil)
    case [mapping_or_type_champ&.to_sym, value]
    in [:integer_number, v] if v.present?
      v.to_i
    in [:decimal_number, v] if v.present?
      v.to_f
    in [:datetime, v] if DateDetectionUtils.likely_string_timestamp?(v)
      timestamp = DateDetectionUtils.convert_unix_timestamp(v)
      return nil if timestamp.nil?
      Time.zone.at(timestamp).iso8601 # (0) # 2 digits of precision, meaning we keep the seconds and 2 digits of milliseconds
    in [:datetime, v]
      DateDetectionUtils.convert_to_iso8601_datetime(v)
    in [:date, v] if DateDetectionUtils.likely_string_timestamp?(v)
      timestamp = DateDetectionUtils.convert_unix_timestamp(v)
      return nil if timestamp.nil?
      Time.zone.at(timestamp).to_date.iso8601
    in [:date, v]
      DateDetectionUtils.convert_to_iso8601_date(v)
    # cases of type from tdc, used to store in a champ
    in [:drop_down_list, Array => arr] if ReferentielMappingUtils.array_of_supported_simple_types?(arr)
      arr.first.to_s
    in [:drop_down_list, v] if type_de_champ&.value_is_in_options?(v) || type_de_champ&.drop_down_other?
      v.to_s
    in [:multiple_drop_down_list, Array => arr] if ReferentielMappingUtils.array_of_supported_simple_types?(arr)
      arr.compact.to_json
    in [:checkbox | :yes_no, v]
      bool = ActiveModel::Type::Boolean.new.cast(v)
      bool.nil? ? nil : (bool ? Champs::BooleanChamp::TRUE_VALUE : Champs::BooleanChamp::FALSE_VALUE)
    in [:text | :textarea | :engagement_juridique | :dossier_link | :email | :phone | :iban | :siret | :formatted | :referentiel, v]
      v.to_s
    # case of type from mapping, used to store for display
    in [:boolean, v]
      ActiveModel::Type::Boolean.new.cast(v)
    in [:array, Array => arr] if ReferentielMappingUtils.array_of_supported_simple_types?(arr)
      Array(arr)
    in [:civilite, v] if v.present?
      normalized = v.to_s.strip.downcase
      case normalized
      when 'm.', 'm', 'mr', 'monsieur', 'male', 'homme'
        Individual::GENDER_MALE
      when 'mme', 'madame', 'mlle', 'mademoiselle', 'female', 'femme'
        Individual::GENDER_FEMALE
      end
    in [:address, v] if v.present?
      v.to_s
    in [:string, v]
      v.to_s
    else
      nil
    end
  end

  def cast_value_for_type_de_champ(value, type_de_champ)
    case type_de_champ.type_champ.to_sym
    when :siret, :referentiel, :address
      { external_id: call_caster(type_de_champ.type_champ, value, type_de_champ) }
    else
      { value: call_caster(type_de_champ.type_champ, value, type_de_champ) }
    end.merge(prefilled: true)
  end

  def cast_displayable_values(json)
    referentiel_mapping_displayable.reduce({}) do |accu, (jsonpath, mapping)|
      json = json.first if json.is_a?(Array) # when json is an array, we take the first element
      casted_value = call_caster(mapping[:type], JSONPathUtil.on_safe(json, jsonpath).first)
      accu[jsonpath] = casted_value if !casted_value.nil?
      accu
    end
  end

  def update_repetition_prefillable_champs(data, repetition_type_de_champ, mappings)
    group_mappings_by_json_array(mappings).flat_map do |array_key, array_mappings|
      json_array = Array(JSONPathUtil.on_safe(data.with_indifferent_access, array_key).first)
      if json_array.is_a?(Array)
        json_array.flat_map do |json_value|
          if json_value.blank?
            []
          else
            row_id = determine_row_id(repetition_type_de_champ)
            array_mappings.map do |jsonpath, type_de_champ|
              raw_value = if JSONPathUtil.json_path_contains_array?(jsonpath)
                JSONPathUtil.on_safe(json_value, JSONPathUtil.extract_key_after_array(jsonpath)).first
              else
                json_value
              end
              update_prefillable_champ(type_de_champ:, raw_value:, row_id:)
            end
          end
        end
      else
        []
      end
    end
  end

  def determine_row_id(repetition_type_de_champ)
    # When referentiel champ is inside a repetition, use current row_id to keep related data together.
    # When outside, create new rows for each array element from external data.
    # Note: Limited to updating current row only when inside repetition.
    if type_de_champ.child?(dossier.revision)
      self.row_id
    else
      dossier.repetition_add_row(repetition_type_de_champ, updated_by:)
    end
  end

  def group_mappings_by_json_array(mappings)
    mappings.group_by { |jsonpath, _| JSONPathUtil.extract_array_name(jsonpath) }
  end

  def update_simple_prefillable_champs(data, mappings)
    mappings.map do |jsonpath, type_de_champ|
      raw_value = JSONPathUtil.on_safe(data, jsonpath).first
      update_prefillable_champ(type_de_champ:, raw_value:)
    end
  end

  def update_prefillable_champ(type_de_champ:, raw_value:, row_id: nil)
    prefill_champ = dossier.champ_for_update(type_de_champ, row_id:, updated_by:)
    prefill_champ.update(cast_value_for_type_de_champ(raw_value, type_de_champ))
    prefill_champ
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
