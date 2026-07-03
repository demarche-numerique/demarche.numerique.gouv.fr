# frozen_string_literal: true

class Columns::GeoJSONColumn < Columns::ChampColumn
  private

  # The feature collection is domain behavior (Champs::CarteChamp), so the
  # champ data is projected back to its champ.
  def typed_value(champ_data)
    Champ.from_data(champ_data)&.to_feature_collection
  end
end
