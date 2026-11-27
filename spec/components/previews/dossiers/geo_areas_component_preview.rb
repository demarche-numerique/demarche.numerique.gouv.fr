# frozen_string_literal: true

class Dossiers::GeoAreasComponentPreview < ViewComponent::Preview
  def default
    champ = mock_champ(
      selections: [
        mock_geo_area(1, "Polygone — 42 m²", "Zone nord"),
        mock_geo_area(2, "Ligne — 120 m", nil),
        mock_geo_area(3, "Point (46°32′18″N 2°25′42″E)", "Entrée principale"),
      ],
      cadastres: [
        mock_geo_area(4, "Parcelle n° 42 – Feuille 000 A11 – 123 m² – commune 75127", nil),
      ],
      rpgs: [
        mock_geo_area(5, "Parcelle agricole n° 12345 - 10 ha", nil),
      ]
    )

    render Dossiers::GeoAreasComponent.new(champ:, editing: false)
  end

  def editing
    champ = mock_champ(
      selections: [
        mock_geo_area(1, "Polygone — 42 m²", "Zone nord"),
        mock_geo_area(2, "Ligne — 120 m", nil),
      ],
      cadastres: [],
      rpgs: []
    )

    render Dossiers::GeoAreasComponent.new(champ:, editing: true)
  end

  private

  def mock_champ(selections:, cadastres:, rpgs:)
    Struct.new(:selections_utilisateur, :cadastres, :rpgs).new(selections, cadastres, rpgs)
  end

  def mock_geo_area(id, label, description)
    Struct.new(:id, :label, :description).new(id, label, description)
  end
end
