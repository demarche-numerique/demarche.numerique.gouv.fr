# frozen_string_literal: true

class ExportedColumnType < ActiveRecord::Type::Value
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
      ExportedColumn.new(column: ColumnType.new.cast(h[:id]), libelle: h[:libelle])
    # from form
    in String
      h = JSON.parse(value).deep_symbolize_keys
      ExportedColumn.new(column: ColumnType.new.cast(h[:id]), libelle: h[:libelle])
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
      })
    else
      raise ArgumentError, "Invalid value for ExportedColumn serialization: #{value}"
    end
  end
end
