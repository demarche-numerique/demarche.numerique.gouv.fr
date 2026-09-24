# frozen_string_literal: true

class Logic::Term
  def to_json
    to_h.to_json
  end

  # A term is never changed once built, so its hash is computed once. Hashing
  # is what Array#&, Array#-, #uniq and #in? run on the terms, and a term
  # nested twenty levels deep is hashed as many times as it has ancestors.
  def hash = @hash ||= hash_value

  def eql?(other)
    hash == other.hash
  end

  def terms = [self]

  # A comparison `champ <operator> constant`, the kind Logic::PossibleValues
  # can be narrowed by (see Logic::BinaryOperator).
  def checkable? = false

  private

  def hash_value = to_h.hash
end
