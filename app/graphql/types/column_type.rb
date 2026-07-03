# frozen_string_literal: true

module Types
  module ColumnType
    include Types::BaseInterface

    global_id_field :id
    field :label, String, "Libellé de la colonne.", null: false
    field :string_value, String, "La valeur de la colonne sous forme texte.", null: true, extras: [:parent]

    def string_value(parent:)
      value = object.value(column_target(parent))
      return if value.blank?
      case object.type
      when :enums
        value.join(', ')
      when :attachments
        value.map(&:url).join(', ')
      else
        value.to_s
      end
    end

    # In the champ → columns path the parent is the projected Champ, but champ
    # columns evaluate against the persisted ChampData. In the changedColumns
    # path the parent is a Traitement and the object is a ChangedColumn holding
    # a precomputed value that ignores the argument.
    def column_target(parent)
      parent.is_a?(Champ) ? parent.champ_data : parent
    end

    definition_methods do
      def resolve_type(object, context)
        case object.type
        when :boolean
          Types::Columns::BooleanColumnType
        when :integer
          Types::Columns::IntegerColumnType
        when :decimal
          Types::Columns::DecimalColumnType
        when :datetime
          Types::Columns::DateTimeColumnType
        when :date
          Types::Columns::DateColumnType
        when :enum
          Types::Columns::EnumColumnType
        when :enums
          Types::Columns::EnumsColumnType
        when :attachments
          Types::Columns::AttachmentsColumnType
        when :geojson
          Types::Columns::GeoJSONColumnType
        else
          Types::Columns::TextColumnType
        end
      end
    end
  end
end
