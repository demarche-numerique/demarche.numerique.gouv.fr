# frozen_string_literal: true

class TypesDeChamp::DossierLinkTypeDeChamp < TypeDeChamp
  def self.icon = 'fr-icon-links-line'
  def self.option_keys = [:procedures_limit, :dossier_link_procedure_ids]

  def prefillable? = true
  def customizable? = true
  store_accessor :options, :procedures_limit, :dossier_link_procedure_ids
  boolean_options :procedures_limit
  def dossier_link_procedure_ids = Array.wrap(super)

  def customization_column(procedure_id:) = canonical_column(procedure_id:)

  def columns(procedure_id:, displayable: true, prefix: nil)
    shared = { procedure_id:, stable_id:, tdc_type: type_champ, displayable:, mandatory: mandatory? }
    [
      Columns::DossierLinkNumberColumn.new(
        **shared,
        label: linked_column_label(prefix, :application_number),
        applicant_label: libelle_with_prefix(prefix),
        type: self.class.column_type,
        options_for_select:
      ),
      Columns::DossierLinkSubmissionDateColumn.new(**shared, label: linked_column_label(prefix, :submitted_on)),
      Columns::DossierLinkProcedureColumn.new(
        **shared,
        label: linked_column_label(prefix, :procedure_title),
        limited_procedure_ids: (dossier_link_procedure_ids if procedures_limit?)
      ),
      Columns::DossierLinkProcedureAgencyColumn.new(**shared, label: linked_column_label(prefix, :procedure_agency)),
    ]
  end

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

  private

  def linked_column_label(prefix, key)
    "#{libelle_with_prefix(prefix)} – #{I18n.t(key, scope: 'activerecord.attributes.procedure_presentation.fields.dossier_link')}"
  end
end
