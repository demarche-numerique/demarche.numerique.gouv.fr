# frozen_string_literal: true

class TypesDeChamp::Civilite < TypeDeChamp
  def self.category = ETAT_CIVIL
  def self.column_type = :enum

  def prefillable? = true
  def options_for_select = Champs::CiviliteChamp.options
  def customizable? = true
end
