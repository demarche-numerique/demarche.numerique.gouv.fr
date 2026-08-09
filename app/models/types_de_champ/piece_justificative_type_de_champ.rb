# frozen_string_literal: true

class TypesDeChamp::PieceJustificativeTypeDeChamp < TypesDeChamp::TypeDeChampBase
  include AddressableColumnConcern

  def estimated_fill_duration(revision)
    FILL_DURATION_LONG
  end

  def tags_for_template = [].freeze

  def filled_champ_value_for_export(champ, path = :value)
    if titre_identite?
      champ.piece_justificative_file.attached? ? "présent" : "absent"
    else
      champ.piece_justificative_file.map { _1.filename.to_s }.join(', ')
    end
  end

  def filled_champ_value_for_api(champ, version: 2)
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

  def champ_value_blank?(champ) = champ.piece_justificative_file.blank?

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
        type: TypeDeChamp.column_type(type_champ),
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
        type: TypeDeChamp.column_type(type_champ),
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
end
