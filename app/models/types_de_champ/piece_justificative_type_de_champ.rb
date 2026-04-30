# frozen_string_literal: true

class TypesDeChamp::PieceJustificativeTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def estimated_fill_duration(revision)
    FILL_DURATION_LONG
  end

  def tags_for_template = [].freeze

  def champ_value_for_export(champ, path = :value)
    if titre_identite?
      champ.piece_justificative_file.attached? ? "présent" : "absent"
    else
      champ.piece_justificative_file.map { _1.filename.to_s }.join(', ')
    end
  end

  def champ_value_for_api(champ, version: 2)
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

  def champ_blank?(champ) = champ.piece_justificative_file.blank?

  def columns(procedure:, displayable: true, prefix: nil)
    cs = []

    if !titre_identite?
      cs << Columns::AttachedManyColumn.new(
        procedure_id: procedure.id,
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
         procedure_id: procedure.id,
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
      cs += JustificatifDomicile.attribute_types
        .map { |attr, type| [attr, active_model_type_to_column_type(type)] }
        .map do |attr, type|
        jsonpath = "$.#{attr}"
        Columns::JSONPathColumn.new(
          procedure_id: procedure.id,
          stable_id:,
          tdc_type: type_champ,
          label: "#{libelle_with_prefix(prefix)} – #{attr}",
          type:,
          jsonpath:,
          displayable: true,
          mandatory: mandatory?
        )
      end
    elsif titre_identite?
      cs += [
        Columns::TitreIdentiteColumn.new(
          procedure_id: procedure.id,
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

  def active_model_type_to_column_type(am_type)
    case am_type
    in ActiveModel::Type::String
      :text
    in ActiveModel::Type::Date
      :date
    in ActiveModel::Type::Boolean
      :boolean
    else
      raise "unknown type #{am_type}"
    end
  end
end
