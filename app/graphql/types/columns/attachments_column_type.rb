# frozen_string_literal: true

module Types::Columns
  class AttachmentsColumnType < Types::BaseObject
    implements Types::ColumnType

    field :value, [Types::File], null: true, extras: [:parent]

    def value(parent:)
      # In the dossier → champs → columns path, `parent` is a Champ and we
      # batch-preload attachments. In the changedColumns path, `parent` is a
      # Traitement and the value is already precomputed by ChangedColumn.
      return object.value(parent) unless parent.is_a?(ChampData)

      dataloader.with(Sources::Association, piece_justificative_file_attachments: :blob).load(parent)
      object.value(parent)
    end
  end
end
