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

  def remap_procedure_id(_new_procedure_id) = self
end
