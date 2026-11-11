# frozen_string_literal: true

class Columns::DossierLinkNumberColumn < Columns::ChampColumn
  def initialize(applicant_label: nil, **)
    super(**)
    @applicant_label = applicant_label
  end

  def applicant_column
    return self if @applicant_label.nil?

    dup.tap { it.relabel(@applicant_label) }
  end

  protected

  def relabel(label) = @label = label

  private

  def sorted_dossiers(dossiers, order)
    direction = order == 'desc' ? 'DESC' : 'ASC'
    dossiers
      .with_type_de_champ(stable_id)
      .order(Arel.sql("CASE WHEN champs.value ~ '^[0-9]+$' THEN champs.value::numeric END #{direction}"), id: order)
  end
end
