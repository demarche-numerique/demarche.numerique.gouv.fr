# frozen_string_literal: true

class Columns::AttachedManyColumn < Columns::ChampColumn
  # An attachments column always exposes a list: no champ data, or champ data written
  # under another champ type, means "no attachments", not a missing value.
  def value(champ_data)
    super || []
  end

  private

  def typed_value(champ_data)
    champ_data.piece_justificative_file.to_a
  end
end
