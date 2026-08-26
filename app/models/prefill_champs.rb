# frozen_string_literal: true

class PrefillChamps
  attr_reader :dossier, :params

  def initialize(dossier, params)
    @dossier = dossier
    @params = params
  end

  def to_a
    build_prefill_values.filter(&:prefillable?).flat_map(&:champs_with_attributes)
  end

  def self.digest(params)
    Digest::SHA256.hexdigest(params.reject { |(key, _)| key.split('_').first != "champ" }.to_json)
  end

  private

  def build_prefill_values
    value_by_stable_id = params
      .map { |prefixed_typed_id, value| [ChampData.stable_id_from_typed_id(prefixed_typed_id), value] }
      .filter { |stable_id, value| stable_id.present? && value.present? }
      .to_h

    dossier
      .champs_for_prefill(value_by_stable_id.keys)
      .map { |champ| [champ, value_by_stable_id[champ.stable_id]] }
      .map { |champ, value| PrefillValue.new(champ:, value:, dossier:) }
  end

  class PrefillValue
    attr_reader :champ, :value, :dossier

    def initialize(champ:, value:, dossier:)
      @champ = champ
      @value = value
      @dossier = dossier
    end

    def prefillable?
      champ.prefillable? && champ_attributes.present?
    end

    # An array of [champ, attributes] pairs; a repetition champ expands to
    # one pair per prefilled subchamp.
    def champs_with_attributes
      champ.repetition? ? champ_attributes : [[champ, champ_attributes]]
    end

    def champ_attributes
      @champ_attributes ||= TypesDeChamp::Prefill
        .build(champ.type_de_champ, dossier.revision)
        .to_assignable_attributes(champ, value)
    end
  end
end
