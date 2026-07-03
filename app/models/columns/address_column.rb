# frozen_string_literal: true

class Columns::AddressColumn < Columns::ChampColumn
  private

  # The raw `value` column is not guaranteed to match the canonical address
  # label stored in `value_json` (eg. BAN addresses). The PDF, the UI and the
  # API all display the label, so exports and dossiers lists must too. Events
  # written under another champ type go through the cast table as usual.
  def typed_value(champ_data) = champ_data.value_json&.dig('label') || super
end
