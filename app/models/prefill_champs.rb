# frozen_string_literal: true

class PrefillChamps
  attr_reader :dossier, :params

  def initialize(dossier, params)
    @dossier = dossier
    @params = params
  end

  def to_a
    build_prefill_values.filter(&:prefillable?).map(&:champ_attributes).flatten
  end

  def self.digest(params)
    Digest::SHA256.hexdigest(params.reject { |(key, _)| key.split('_').first != "champ" }.to_json)
  end

  private

  def build_prefill_values
    value_by_stable_id = params
      .map { |prefixed_typed_id, value| [Champ.stable_id_from_typed_id(prefixed_typed_id), value] }
      .filter { |stable_id, value| stable_id.present? && value.present? }
      .to_h

    dossier
      .champs_for_prefill(value_by_stable_id.keys)
      .map { |champ| [champ, value_by_stable_id[champ.stable_id]] }
      .map { |champ, value| PrefillValue.new(champ:, value:, dossier:) }
  end

  class PrefillValue
    NEED_VALIDATION_TYPES_DE_CHAMPS = [
      TypeDeChamp.type_champs.fetch(:decimal_number),
      TypeDeChamp.type_champs.fetch(:integer_number),
      TypeDeChamp.type_champs.fetch(:date),
      TypeDeChamp.type_champs.fetch(:datetime),
      TypeDeChamp.type_champs.fetch(:civilite),
      TypeDeChamp.type_champs.fetch(:yes_no),
      TypeDeChamp.type_champs.fetch(:checkbox),
      TypeDeChamp.type_champs.fetch(:pays),
      TypeDeChamp.type_champs.fetch(:regions),
      TypeDeChamp.type_champs.fetch(:departements),
      TypeDeChamp.type_champs.fetch(:multiple_drop_down_list),
      TypeDeChamp.type_champs.fetch(:epci),
      TypeDeChamp.type_champs.fetch(:dossier_link),
    ]

    attr_reader :champ, :value, :dossier

    def initialize(champ:, value:, dossier:)
      @champ = champ
      @value = value
      @dossier = dossier
    end

    def prefillable?
      champ.prefillable? && champ_attributes.present? && valid?
    end

    def champ_attributes
      @champ_attributes ||= TypesDeChamp::PrefillTypeDeChamp
        .build(champ.type_de_champ, dossier.revision)
        .to_assignable_attributes(champ, value)
    end

    private

    def valid?
      return true unless NEED_VALIDATION_TYPES_DE_CHAMPS.include?(champ.type_champ)

      champ.assign_attributes(champ_attributes)
      champ.valid?(:prefill)
    end
  end
end
