# frozen_string_literal: true

class TypesDeChamp::PieceJustificativeTypeDeChamp < TypeDeChamp
  def self.option_keys = [:old_pj, :skip_pj_validation, :skip_content_type_pj_validation, :pj_limit_formats, :pj_format_families, :pj_auto_purge]
  def self.column_type = :attachments

  FILE_MAX_SIZE = 200.megabytes
  IDENTITY_FILE_MAX_SIZE = 20.megabytes

  enum :nature, %w[non_specifie titre_identite rib justificatif_domicile avis_impot].index_by(&:itself)

  store_accessor :options,
                 :old_pj,
                 :skip_pj_validation,
                 :skip_content_type_pj_validation,
                 :pj_limit_formats,
                 :pj_format_families,
                 :pj_auto_purge

  validates :piece_justificative_template, size: { less_than: FILE_MAX_SIZE }, on: :update
  validates :piece_justificative_template, content_type: -> (_record) { AUTHORIZED_CONTENT_TYPES }, on: :update
  validates :piece_justificative_template, empty_file: true, on: :update

  before_validation :reset_format_options_if_forced_nature

  include AddressableColumnConcern

  def estimated_fill_duration(revision)
    FILL_DURATION_LONG
  end

  def tags_for_template = [].freeze

  def libelle_as_filename
    libelle.gsub(/[[:space:]]+/, ' ')
      .truncate(30, omission: '', separator: ' ')
      .parameterize
  end

  def typed_champ_value_for_export(champ, path = :value)
    if titre_identite?
      champ.piece_justificative_file.attached? ? "présent" : "absent"
    else
      champ.piece_justificative_file.map { _1.filename.to_s }.join(', ')
    end
  end

  def typed_champ_value_for_api(champ, version: 2)
    return if version == 2

    # API v1 don't support multiple PJ
    attachment = champ.piece_justificative_file.first
    return if attachment.nil?
    # API v1 should neither return attachments for titre identité
    return if titre_identite?

    if attachment.virus_scanner.safe? || attachment.virus_scanner.pending?
      attachment.url
    end
  end

  def typed_champ_blank?(champ) = champ.piece_justificative_file.blank?

  boolean_options :pj_limit_formats

  def pj_format_families
    Array.wrap(options[:pj_format_families]).map(&:to_s)
  end

  def forced_format_nature? = titre_identite? || rib? || justificatif_domicile? || avis_impot?

  def pj_auto_purge?
    titre_identite? || ActiveModel::Type::Boolean.new.cast(pj_auto_purge) || false
  end

  def ocr_compatible? = rib? || justificatif_domicile? || avis_impot?

  def revision_diff_options
    values = {
      piece_justificative_template: RevisionDiffValue.new(piece_justificative_template.blob&.checksum) { piece_justificative_template.blob&.filename },
      nature:,
    }
    # les natures forcées imposent leurs règles de format : on compare des
    # valeurs normalisées des deux côtés, sinon quitter une nature forcée
    # rapporte un changement fantôme (nil vs []).
    if forced_format_nature?
      values.merge!(pj_limit_formats: false, pj_format_families: [], pj_auto_purge: false)
    else
      values.merge!(pj_limit_formats: pj_limit_formats?, pj_format_families:, pj_auto_purge: pj_auto_purge?)
    end
    values
  end

  def max_file_size_bytes
    if titre_identite?
      IDENTITY_FILE_MAX_SIZE
    else
      FILE_MAX_SIZE
    end
  end

  def allowed_extensions
    allowed_content_types
      .filter_map { |mime| MiniMime.lookup_by_content_type(mime)&.extension }
      .uniq
      .map { |ext| ".#{ext}" }
  end

  def allowed_content_types
    if titre_identite?
      families_to_content_types(%w[image_scan])
    elsif ocr_compatible?
      families_to_content_types(%w[document_texte image_scan])
    elsif pj_limit_formats? && pj_format_families.present?
      families_to_content_types(pj_format_families)
    else
      AUTHORIZED_CONTENT_TYPES
    end
  end

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    if titre_identite?
      Columns::TitreIdentiteColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: "#{libelle_with_prefix(prefix)} – filled",
        type: :text,
        displayable: true,
        mandatory: mandatory?
      )
    else
      Columns::AttachedManyColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: libelle_with_prefix(prefix),
        type: self.class.column_type,
        displayable: false,
        filterable: false,
        mandatory: mandatory?
      )
    end
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    cs = []

    if !titre_identite?
      cs << Columns::AttachedManyColumn.new(
        procedure_id:,
        stable_id:,
        tdc_type: type_champ,
        label: libelle_with_prefix(prefix),
        type: self.class.column_type,
        displayable: false,
        filterable: false,
        mandatory: mandatory?
      )
    end

    if rib?
      cs += [
        ['Titulaire', '$.rib.account_holder'],
        ['IBAN', '$.rib.iban'],
        ['BIC', '$.rib.bic'],
        ['Nom de la Banque', '$.rib.bank_name'],
      ].map do |label, jsonpath|
        Columns::JSONPathColumn.new(
         procedure_id:,
         stable_id:,
         tdc_type: type_champ,
         label: "#{libelle_with_prefix(prefix)} – #{label}",
         type: :text,
         jsonpath:,
         displayable: true,
         mandatory: mandatory?
       )
      end
    elsif justificatif_domicile?
      cs += [
        [:beneficiary, :text],
        [:label, :text],
        [:issue_date, :date],
      ].map do |attribute, type|
        Columns::JSONPathColumn.new(
          procedure_id:,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} – #{JustificatifDomicile.human_attribute_name(attribute)}",
          type:,
          jsonpath: "$.#{attribute}",
          displayable: true,
          mandatory: mandatory?
        )
      end
      cs.concat(addressable_columns(procedure_id:, displayable:, prefix:))
    elsif avis_impot?
      cs += [
        [:declarant_1, :text],
        [:declarant_2, :text],
        [:reference_avis, :text],
        [:annee_des_revenus, :integer],
        [:nombre_de_parts, :decimal],
        [:revenu_fiscal_de_reference, :integer],
        [:date_mise_en_recouvrement, :date],
      ].map do |attribute, type|
        Columns::JSONPathColumn.new(
          procedure_id:,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} – #{AvisImpot.human_attribute_name(attribute)}",
          type:,
          jsonpath: "$.#{attribute}",
          displayable: true,
          mandatory: mandatory?
        )
      end
      cs.concat(addressable_columns(procedure_id:, displayable:, prefix:))
    elsif titre_identite?
      cs += [
        Columns::TitreIdentiteColumn.new(
          procedure_id:,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} – filled",
          type: :text,
          displayable: true,
          mandatory: mandatory?
        ),
      ]
    end

    cs
  end

  private

  def families_to_content_types(families)
    return AUTHORIZED_CONTENT_TYPES if families.blank?

    families
      .flat_map { |f| FORMAT_FAMILIES[f.to_sym] || [] }
      .presence || AUTHORIZED_CONTENT_TYPES
  end

  def reset_format_options_if_forced_nature
    if titre_identite? || rib?
      self.pj_limit_formats = nil
      self.pj_format_families = []
    end
  end
end
