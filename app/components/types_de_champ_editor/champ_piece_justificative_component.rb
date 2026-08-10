# frozen_string_literal: true

class TypesDeChampEditor::ChampPieceJustificativeComponent < TypesDeChampEditor::BaseChampComponent
  delegate :titre_identite?, :rib?, :pj_limit_formats?, :ocr_compatible?,
    :nature, to: :type_de_champ

  def render?
    type_de_champ.piece_justificative?
  end

  private

  def nature_dom_id = dom_id(type_de_champ, :nature)

  def natures_for_select
    TypesDeChamp::PieceJustificativeTypeDeChamp.natures.keys
      .map { |k| [t("activerecord.attributes.type_de_champ.natures.#{k}"), k] }
  end

  def piece_justificative_template_options
    {
      attached_file: type_de_champ.piece_justificative_template,
      auto_attach_url: helpers.auto_attach_url(type_de_champ, procedure_id: procedure.id),
      view_as: :download,
    }
  end

  def format_families
    FORMAT_FAMILIES.keys.map do |key|
      [
        key,
        t("activerecord.attributes.type_de_champ.format_families.#{key}"),
        key.to_s.in?(type_de_champ.pj_format_families),
        FORMAT_FAMILY_EXAMPLES[key],
      ]
    end
  end
end
