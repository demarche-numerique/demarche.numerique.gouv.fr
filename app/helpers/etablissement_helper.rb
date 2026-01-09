# frozen_string_literal: true

module EtablissementHelper
  def value_for_bilan_key(bilan, key)
    if bilan_v3?(bilan)
      return extract_resultat_exercice(bilan['data']) if key == "resultat_exercice"
      bilan["data"][key].presence || bilan["data"]["valeurs_calculees"][0][key].present? ? bilan["data"]["valeurs_calculees"][0][key]["valeur"] : nil
    else
      bilan[key]
    end
  end

  def year_for_bilan(bilan)
    if bilan_v3?(bilan)
      bilan["data"].fetch("annee")
    else
      bilan["date_arret_exercice"]
    end
  end

  # trouver la declaration 2051, et prendre la premiere valeur du bilan identifié par le code code_nref: 300476
  # autrement connu comme le resultat d’un exercice dans un bilan comptable "funky magic accountant lingo"
  def extract_resultat_exercice(bilan)
    declaration_2051 = bilan.dig('declarations').find { _1["numero_imprime"] == "2051" }
    return nil if declaration_2051.nil?

    total_general_data = declaration_2051.dig("donnees").find { _1["code_nref"] == "300476" }
    return nil if total_general_data.nil?

    total_general_data.dig("valeurs", 0)
  end

  def bilan_v3?(bilan)
    bilan&.key?("data")
  end

  def pretty_siret(siret)
    return if siret.blank?
    siret = siret.gsub(/[[:space:]]/, "")
    "#{siret[0..2]} #{siret[3..5]} #{siret[6..8]} #{siret[9..]}"
  end

  def pretty_currency(value, unit: '€')
    number_to_currency(value, locale: :fr, unit: unit, precision: 0)
  end

  def pretty_currency_unit(unit)
    dict = { 'kEuros' => 'k€', 'euros' => '€' }
    dict[unit]
  end

  def raison_sociale_or_name(etablissement)
    return etablissement.association_titre if etablissement.association_titre.present?
    return "#{etablissement.enseigne} - #{etablissement.localite}" if etablissement.enseigne.present?
    return etablissement.entreprise_raison_sociale if etablissement.entreprise_raison_sociale.present?
    "#{etablissement.entreprise_nom} #{etablissement.entreprise_prenom}"
  end

  def effectif(etablissement)
    {
      'NN' => "Unités non employeuses (pas de salarié au cours de l’année de référence et pas d’effectif au 31/12).",
      '00' => "0 salarié (n’ayant pas d’effectif au 31/12 mais ayant employé des salariés au cours de l’année de référence)",
      '01' => '1 ou 2 salariés',
      '02' => '3 à 5 salariés',
      '03' => '6 à 9 salariés',
      '11' => '10 à 19 salariés',
      '12' => '20 à 49 salariés',
      '21' => '50 à 99 salariés',
      '22' => '100 à 199 salariés',
      '31' => '200 à 249 salariés',
      '32' => '250 à 499 salariés',
      '41' => '500 à 999 salariés',
      '42' => '1 000 à 1 999 salariés',
      '51' => '2 000 à 4 999 salariés',
      '52' => '5 000 à 9 999 salariés',
      '53' => '10 000 salariés et plus',
    }[etablissement.entreprise_code_effectif_entreprise]
  end

  def pretty_date_exercice(date)
    date.sub(/(?<year>\d{4})(?<month>\d{2})/, '\k<year>') if date.present?
  end

  def humanized_entreprise_etat_administratif(etablissement)
    case etablissement.entreprise_etat_administratif&.to_sym
    when :actif
      "en activité"
    when :fermé
      "fermé"
    end
  end

  def entreprise_etat_administratif_badge_class(etablissement)
    case etablissement.entreprise_etat_administratif&.to_sym
    when :actif
      "fr-badge--success"
    when :fermé
      "fr-badge--error"
    end
  end
end
