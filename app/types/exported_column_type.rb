# frozen_string_literal: true

class ExportedColumnType < ActiveRecord::Type::Value
  # this legacy column exported the bare code, its canonical column exports the label
  LEGACY_RAW_JSONPATH = '$.code_departement'

  # form_input or setter -> type
  def cast(value)
    value = value.deep_symbolize_keys if value.respond_to?(:deep_symbolize_keys)

    case value
    in ExportedColumn
      value
    in NilClass # default value
      nil
    # from db
    in { id: String | Hash, libelle: String } => h
      build_exported_column(h)
    # from form
    in String
      build_exported_column(JSON.parse(value).deep_symbolize_keys)
    end
  end

  # db -> ruby
  # Returns nil when the referenced column no longer exists in the procedure
  # (e.g. a type_de_champ was removed after the export template was saved).
  # Callers of exported_columns must compact the resulting array.
  def deserialize(value)
    cast(value&.then { JSON.parse(_1) })
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # ruby -> db
  def serialize(value)
    case value
    in NilClass
      nil
    in ExportedColumn
      JSON.generate({
        id: value.column.h_id,
        libelle: value.libelle,
        raw: (true if value.raw),
      }.compact)
    else
      raise ArgumentError, "Invalid value for ExportedColumn serialization: #{value}"
    end
  end

  private

  def build_exported_column(h)
    ExportedColumn.new(
      column: ColumnType.new.cast(h[:id]),
      libelle: h[:libelle],
      raw: h[:raw] || h[:id].to_s.include?(LEGACY_RAW_JSONPATH)
    )
  end
end
