# frozen_string_literal: true

class Columns::TitreIdentiteColumn < Columns::ChampColumn
  # The column reports presence: no champ data, or champ data written under another
  # champ type, is a value ("absent"), not a missing value.
  def value(champ_data)
    super || 'absent'
  end

  private

  def typed_value(champ_data)
    champ_data.piece_justificative_file.attached? ? 'présent' : 'absent'
  end
end
