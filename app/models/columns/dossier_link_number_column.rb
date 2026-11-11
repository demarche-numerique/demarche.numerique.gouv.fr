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
end
