# frozen_string_literal: true

class TypesDeChamp::DossierLinkTypeDeChamp < TypeDeChamp
  def self.icon = 'fr-icon-links-line'
  def self.option_keys = [:procedures_limit, :dossier_link_procedure_ids]

  def prefillable? = true
  def customizable? = true
  store_accessor :options, :procedures_limit, :dossier_link_procedure_ids
  boolean_options :procedures_limit
  def dossier_link_procedure_ids = Array.wrap(super)

  def revision_diff_options
    {
      procedures_limit: procedures_limit?,
      dossier_link_procedure_ids: RevisionDiffValue.new(dossier_link_procedure_ids) do
        libelles = Procedure.with_discarded.where(id: dossier_link_procedure_ids).pluck(:id, :libelle).to_h
        dossier_link_procedure_ids.map { { id: it, libelle: libelles[it] } }
      end,
    }
  end

  def dossier_link_procedure_ids=(value)
    super(Array.wrap(value).map(&:to_i).reject(&:zero?).uniq)
  end
end
