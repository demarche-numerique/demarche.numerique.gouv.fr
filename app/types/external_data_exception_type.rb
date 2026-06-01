# frozen_string_literal: true

class ExternalDataExceptionType < ActiveRecord::Type::Value
  # value can come from:
  # setter: ExternalDataException or { error:, code:, kind?: } (Hash),
  # from db: { reason:, code: } (Hash) (legacy) or { error:, code:, kind?: } (Hash)
  def cast(value)
    case value
    in NilClass
      nil
    in ExternalDataException
      value
    in { error: String => error, code: Integer => code, kind: } => h
      ExternalDataException.new(error:, code:, kind: cast_kind(h[:kind]))
    in { error: String => error, code: Integer => code }
      ExternalDataException.new(error:, code:, kind: nil)
    in { reason: String => error, code: Integer => code }
      ExternalDataException.new(error:, code:, kind: nil)
    in String => json_string
      h = JSON.parse(json_string, symbolize_names: true) rescue { reason: json_string, code: nil }
      ExternalDataException.new(
        error: h[:error] || h[:reason],
        code: h[:code],
        kind: cast_kind(h[:kind])
      )
    else
      raise ArgumentError, "Invalid value for ExternalDataException casting: #{value}"
    end
  end

  # db -> ruby
  def deserialize(value) = cast(value)

  # ruby -> db
  def serialize(value)
    case value
    in NilClass
      nil
    in ExternalDataException
      JSON.generate({ code: value.code, error: value.error, kind: value.kind })
    else
      raise ArgumentError, "Invalid value for ExternalDataException serialization: #{value}"
    end
  end

  private

  def cast_kind(raw)
    return nil if raw.nil?
    sym = raw.to_sym
    ExternalDataException::KINDS.include?(sym) ? sym : nil
  end
end
