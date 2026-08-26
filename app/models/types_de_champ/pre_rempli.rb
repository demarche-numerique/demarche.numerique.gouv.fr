# frozen_string_literal: true

class TypesDeChamp::PreRempli < TypeDeChamp
  def self.category = REFERENTIEL_EXTERNE
  def self.option_keys = [:drop_down_options, :pre_rempli_hidden]
  def self.feature_flag = :pre_rempli_type_de_champ
  def self.column_type = :enum
  def self.conditionable? = true

  store_accessor :options, :drop_down_options, :pre_rempli_hidden
  boolean_options :pre_rempli_hidden

  def condition_value_type = :enum
  def condition_options = options_for_select
  def prefillable? = true
  def options_for_select = drop_down_options.uniq.map { [_1, _1] }
  def cannot_be_mandatory? = true

  def drop_down_options = Array.wrap(super)

  def drop_down_options=(options)
    super(Array.wrap(options).filter_map { it.to_s.squish.presence })
  end

  def drop_down_options_from_text=(text)
    self.drop_down_options = text.to_s.lines
  end
end
