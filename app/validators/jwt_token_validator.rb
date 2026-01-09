# frozen_string_literal: true

class JwtTokenValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    begin
      JWT.decode value, nil, false
    rescue
      record.errors.add attribute, :invalid, message: (options[:message] || "n’est pas un jeton valide")
    end
  end
end
