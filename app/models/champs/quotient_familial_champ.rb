# frozen_string_literal: true

class Champs::QuotientFamilialChamp < Champ
  def fc_data_approved? = ActiveModel::Type::Boolean.new.cast(value)

  def fc_data_correct?
    fetched? && fc_data_approved?
  end

  def fc_data_incorrect?
    fetched? && fc_data_approved? == false
  end
end
