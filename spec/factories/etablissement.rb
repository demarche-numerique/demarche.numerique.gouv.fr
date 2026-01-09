# frozen_string_literal: true

FactoryBot.define do
  factory :etablissement do
    siret { '44011762001530' }
    siege_social { true }
    naf { '4950Z' }
    libelle_naf { 'Transports par conduites' }
    adresse { "GRTGAZ\r IMMEUBLE BORA\r 6 RUE RAOUL NORDLING\r 92270 BOIS COLOMBES\r" }
    numero_voie { '6' }
    type_voie { 'RUE' }
    nom_voie { 'RAOUL NORDLING' }
    complement_adresse { 'IMMEUBLE BORA' }
    code_postal { '92270' }
    localite { 'BOIS COLOMBES' }
    code_insee_localite { '92009' }

    entreprise_siren { '440117620' }
    entreprise_capital_social { 537_100_000 }
    entreprise_numero_tva_intracommunautaire { 'FR27440117620' }
    entreprise_forme_juridique { 'SA à conseil d’administration (s.a.i.)' }
    entreprise_forme_juridique_code { '5599' }
    entreprise_nom_commercial { 'GRTGAZ' }
    entreprise_raison_sociale { 'GRTGAZ' }
    entreprise_siret_siege_social { '44011762001530' }
    entreprise_code_effectif_entreprise { '51' }
    entreprise_date_creation { "1990-04-24" }
    entreprise_etat_administratif { :actif }

    trait :with_exercices do
      exercices { [association(:exercice)] }
    end

    trait :with_effectif_mensuel do
      entreprise_effectif_mensuel { 100.5 }
      entreprise_effectif_mois { '03' }
      entreprise_effectif_annee { '2020' }
    end

    trait :non_diffusable do
      diffusable_commercialement { false }
    end
  end

  trait :is_association do
    association_rna { "W072000535" }
    association_titre { "ASSOCIATION POUR LA PROMOTION DE SPECTACLES AU CHATEAU DE ROCHEMAURE" }
    association_objet { "mise en oeuvre et réalisation de spectacles au chateau de rochemaure" }
    association_date_creation { "1990-04-24" }
    association_date_declaration { "2014-11-28" }
    association_date_publication { "1990-05-16" }
  end
end
