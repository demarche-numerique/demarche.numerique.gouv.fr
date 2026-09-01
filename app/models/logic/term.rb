# frozen_string_literal: true

class Logic::Term
  def to_json
    to_h.to_json
  end

  def hash
    to_json.hash
  end

  def eql?(other)
    hash == other.hash
  end

  def terms = [self]

  # An atom `champ <operator> constant`, the kind a domain can be narrowed by.
  def constraining? = false
end
