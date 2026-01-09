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
end
