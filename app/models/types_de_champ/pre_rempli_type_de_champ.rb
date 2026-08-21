# frozen_string_literal: true

class TypesDeChamp::PreRempliTypeDeChamp < TypeDeChamp
  def self.category = REFERENTIEL_EXTERNE
  def self.editable_option_keys = [:drop_down_options, :pre_rempli_hidden]
  def self.feature_flag = :pre_rempli_type_de_champ
  def self.column_type = :enum

  include TypesDeChamp::DropDownOptionsConcern

  def prefillable? = true
  def options_for_select = drop_down_options.uniq.map { [_1, _1] }
  def cannot_be_mandatory? = true
  boolean_options :pre_rempli_hidden
end
