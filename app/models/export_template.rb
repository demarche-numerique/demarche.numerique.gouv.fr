# frozen_string_literal: true

class ExportTemplate < ApplicationRecord
  include TagsSubstitutionConcern

  self.ignored_columns += ["content"]

  belongs_to :groupe_instructeur
  has_one :procedure, through: :groupe_instructeur
  has_many :exports, dependent: :nullify

  enum :kind, { zip: 'zip', csv: 'csv', xlsx: 'xlsx', ods: 'ods' }, prefix: :template

  attribute :dossier_folder, :export_item
  attribute :export_pdf, :export_item
  attribute :pjs, :export_item, array: true
  attribute :attestation, :export_item

  attribute :exported_columns, :exported_column, array: true

  after_initialize :set_default_export_items

  before_validation :ensure_pjs_are_legit

  validates_with ExportTemplateValidator

  scope :shareable, -> { where(shared: true) }

  DOSSIER_STATE = Dossier.states.fetch(:en_construction)

  # when a pj has been added to a revision, it will not be present in the previous pjs
  # a default value is provided.
  def pj(tdc)
    pjs.find { _1.stable_id == tdc.stable_id } || ExportItem.default_pj(tdc)
  end

  def self.default(name: nil, kind: 'zip', groupe_instructeur:)
    # TODO: remove default values for tabular export
    pjs = groupe_instructeur.procedure.exportables_pieces_jointes.map { |tdc| ExportItem.default_pj(tdc) }

    export_template = new(name:, kind:, groupe_instructeur:, pjs:)
    export_template.set_default_export_items
    export_template
  end

  def tabular?
    kind != 'zip'
  end

  def tags
    tags_categorized.slice(:individual, :etablissement, :dossier).values.flatten
  end

  def pj_tags
    tags.push(
      libelle: 'nom original du fichier',
      id: 'original-filename'
    )
  end

  def attachment_path(dossier, attachment, index: 0, row_index: nil, champ: nil)
    file_path = if attachment.name == 'pdf_export_for_instructeur' && export_pdf.enabled?
      export_pdf.path(dossier, attachment:)
    elsif attachment.record_type == 'Attestation' && attestation&.enabled?
      attestation.path(dossier, attachment:)
    elsif attachment.record_type == 'Champ' && pj(champ.type_de_champ).enabled?
      pj(champ.type_de_champ).path(dossier, attachment:, index:, row_index:)
    elsif not_from_champ?(attachment)
      ActiveStorage::DownloadableFile.timestamped_filename(attachment)
    else
      nil
    end

    File.join(dossier_folder.path(dossier), file_path) if file_path.present?
  end

  def dossier_exported_columns = exported_columns.filter { _1.column.dossier_column? }

  def columns_for_stable_id(stable_id)
    exported_columns
      .filter { _1.column.champ_column? }
      .filter { _1.column.stable_id == stable_id }
  end

  def in_export?(exported_column)
    @template_exported_columns ||= exported_columns.map(&:column)
    @template_exported_columns.include?(exported_column.column)
  end

  # Filter out stale column references (e.g. type_de_champ removed from procedure after template was saved)
  def exported_columns
    super.compact
  end

  def set_default_export_items
    self.dossier_folder ||= ExportItem.default(prefix: 'dossier')
    self.export_pdf ||= ExportItem.default(prefix: 'export')
    self.attestation ||= ExportItem.default(prefix: 'attestation')
    self.pjs ||= []
  end

  private

  def ensure_pjs_are_legit
    legitimate_pj_stable_ids = procedure.exportables_pieces_jointes_for_all_versions.map(&:stable_id)

    self.pjs = pjs.filter { _1.stable_id.in?(legitimate_pj_stable_ids) }
  end

  def not_from_champ?(attachment)
    (attachment.record_type == 'Avis' && avis_attachments) || (attachment.record_type == 'Commentaire' && commentaires_attachments) || (attachment.name == 'justificatif_motivation' && justificatif_motivation)
  end
end
