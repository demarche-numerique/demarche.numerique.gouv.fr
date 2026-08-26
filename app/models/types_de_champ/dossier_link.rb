# frozen_string_literal: true

class TypesDeChamp::DossierLink < TypeDeChamp
  def self.category = STRUCTURE
  def self.option_keys = [:procedures_limit, :dossier_link_procedure_ids]

  def prefillable? = true
  def customizable? = true
  store_accessor :options, :procedures_limit, :dossier_link_procedure_ids
  boolean_options :procedures_limit
  def dossier_link_procedure_ids = Array.wrap(super)

  def dossier_link_procedure_ids=(value)
    super(Array.wrap(value).map(&:to_i).reject(&:zero?).uniq)
  end
end
