# frozen_string_literal: true

# The champ is not filled (left blank, or not displayed): every atom on it is
# false, which is what an empty domain yields. Also stands for champs whose
# type no condition can reason about.
module Logic::Domain::Blank
  extend self

  def empty? = true

  def restrict(_operator_class, _value) = self

  def union(_other) = nil

  def to_s(_type_de_champ = nil) = I18n.t('logic.domain.blank')
end
