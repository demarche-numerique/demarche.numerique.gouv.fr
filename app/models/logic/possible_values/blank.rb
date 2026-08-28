# frozen_string_literal: true

# The champ is not filled (left blank, or not displayed): every comparison on
# it is false, which is what an empty set of values yields. Also stands for
# champs whose type no condition can reason about.
module Logic::PossibleValues::Blank
  extend self

  def empty? = true

  def limits = nil

  def restrict(_operator_class, _value) = self

  def union(_other) = nil

  def to_s(_type_de_champ = nil) = I18n.t('logic.possible_values.blank')
end
