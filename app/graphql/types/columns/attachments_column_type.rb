# frozen_string_literal: true

module Types::Columns
  class AttachmentsColumnType < Types::BaseObject
    implements Types::ColumnType

    field :value, [Types::File], null: true, extras: [:parent]

    def value(parent:)
      # Batch-preload attachments in the champ → columns path.
      champ_data = column_target(parent)
      dataloader.with(Sources::Association, piece_justificative_file_attachments: :blob).load(champ_data) if champ_data.is_a?(ChampData)
      object.value(champ_data)
    end
  end
end
