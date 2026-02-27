# frozen_string_literal: true

class Champs::TitreIdentiteChamp < Champ
  FILE_MAX_SIZE = 20.megabytes
  ACCEPTED_FORMATS = ['image/png', 'image/jpeg']

  has_many_attached :piece_justificative_file

  validates :piece_justificative_file,
    content_type: ACCEPTED_FORMATS,
    size: { less_than: FILE_MAX_SIZE },
    if: :validate_champ_value?

  def main_value_name
    :piece_justificative_file
  end

  def search_terms
    # We don’t know how to search inside documents yet
  end
end
