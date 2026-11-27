# frozen_string_literal: true

class ProcedureOverview
  attr_reader :start_date

  attr_accessor :procedure,
    :created_dossiers_count,
    :dossiers_en_instruction_count,
    :old_dossiers_en_instruction,
    :dossiers_en_construction_count,
    :old_dossiers_en_construction

  def initialize(procedure, dossiers)
    @start_date = 1.week.ago.beginning_of_week
    @procedure = procedure

    dossiers_en_instruction = dossiers.state_en_instruction
    dossiers_en_construction = dossiers.state_en_construction

    @dossiers_en_instruction_count = dossiers_en_instruction.count
    @dossiers_en_construction_count = dossiers_en_construction.count

    @old_dossiers_en_instruction =
      dossiers_en_instruction.where(en_instruction_at: ...1.week.ago).select(:id).to_a

    @old_dossiers_en_construction =
      dossiers_en_construction.where(depose_at: ...1.week.ago).select(:id).to_a

    @created_dossiers_count =
      dossiers.where(created_at: @start_date..).count
  end

  def had_some_activities?
    [
      @dossiers_en_instruction_count,
      @dossiers_en_construction_count,
      @created_dossiers_count,
    ].reduce(:+) > 0
  end
end
