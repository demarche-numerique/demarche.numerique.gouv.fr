# frozen_string_literal: true

class TypesDeChamp::CiviliteTypeDeChamp < TypeDeChamp
  def self.category = IDENTIFICATION
  def self.icon = 'fr-icon-user-line'
  def self.column_type = :enum

  def prefillable? = true
  def options_for_select = Champs::CiviliteChamp.options
  def customizable? = true
end
