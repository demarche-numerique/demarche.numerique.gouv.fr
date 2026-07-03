# frozen_string_literal: true

class Etablissement < ApplicationRecord
  belongs_to :dossier, optional: true, touch: true

  has_one :champ, class_name: 'Champs::SiretChamp', touch: true, inverse_of: :etablissement

  has_many :exercices, dependent: :destroy

  has_one_attached :entreprise_attestation_sociale
  has_one_attached :entreprise_attestation_fiscale

  accepts_nested_attributes_for :exercices

  validates :siret, presence: true
  validates :dossier_id, uniqueness: { allow_nil: true }

  enum :entreprise_etat_administratif, {
    actif: "actif",
    fermé: "fermé",
  }, prefix: true

  after_commit -> { dossier&.index_search_terms_later }

  alias_attribute :code_naf, :naf

  # See https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/10591#discussion_r1819399688
  # SIRET is already exposed as base column.
  DISPLAYABLE_COLUMNS = {
    "entreprise_raison_sociale" => { type: :text },
    "entreprise_siren" => { type: :text },
    "entreprise_nom_commercial" => { type: :text },
    "entreprise_forme_juridique" => { type: :text },
    "entreprise_date_creation" => { type: :date, filterable: false },
    "libelle_naf" => { type: :text },
    "libelle_naf_2025" => { type: :text },
  }.freeze

  EXPORTABLE_ETABLISSEMENT_COLUMNS = {
    "siege_social" => { type: :boolean },
    "code_naf" => { type: :text },
    "adresse" => { type: :text },
    "numero_voie" => { type: :text },
    "type_voie" => { type: :text },
    "nom_voie" => { type: :text },
    "complement_adresse" => { type: :text },
    "localite" => { type: :text },
    "code_insee_localite" => { type: :text },
    "entreprise_capital_social" => { type: :integer },
    "entreprise_numero_tva_intracommunautaire" => { type: :text },
    "entreprise_forme_juridique_code" => { type: :text },
    "entreprise_code_effectif_entreprise" => { type: :text },
    "entreprise_etat_administratif" => { type: :text },
    "entreprise_siret_siege_social" => { type: :text },
    "entreprise_nom" => { type: :text },
    "entreprise_prenom" => { type: :text },
    "naf_2025" => { type: :text },
  }.freeze

  EXPORTABLE_ASSOCIATION_COLUMNS = {
    "association_rna" => { type: :text },
    "association_titre" => { type: :text },
    "association_objet" => { type: :text },
    "association_date_creation" => { type: :text, filterable: false },
    "association_date_declaration" => { type: :text, filterable: false },
    "association_date_publication" => { type: :text, filterable: false },
  }.freeze

  def entreprise_raison_sociale
    read_attribute(:entreprise_raison_sociale).presence || raison_sociale_for_ei
  end

  def raison_sociale_for_ei
    if entreprise_nom || entreprise_prenom
      [entreprise_nom, entreprise_prenom].join(' ')
    end
  end

  def search_terms
    [
      entreprise_siren,
      entreprise_numero_tva_intracommunautaire,
      entreprise_forme_juridique,
      entreprise_forme_juridique_code,
      entreprise_nom_commercial,
      entreprise_raison_sociale,
      entreprise_siret_siege_social,
      entreprise_nom,
      entreprise_prenom,
      association_rna,
      association_titre,
      association_objet,
      siret,
      enseigne,
      naf,
      libelle_naf,
      naf_2025,
      libelle_naf_2025,
      adresse,
      code_postal,
      localite,
      code_insee_localite,
      nom_pays,
    ]
  end

  def spreadsheet_columns
    [
      ['Dossier ID', :dossier_id_for_export],
      ['Champ', :libelle_for_export],
      ['Établissement SIRET', :siret],
      ['Etablissement enseigne', :enseigne],
      ['Établissement siège social', :siege_social],
      ['Établissement NAF', :naf],
      ['Établissement libellé NAF', :libelle_naf],
      ['Établissement Adresse', :adresse],
      ['Établissement numero voie', :numero_voie],
      ['Établissement type voie', :type_voie],
      ['Établissement nom voie', :nom_voie],
      ['Établissement complément adresse', :complement_adresse],
      ['Établissement code postal', :code_postal],
      ['Établissement localité', :localite],
      ['Établissement code INSEE localité', :code_insee_localite],
      ['Entreprise SIREN', :entreprise_siren],
      ['Entreprise capital social', :entreprise_capital_social],
      ['Entreprise numero TVA intracommunautaire', :entreprise_numero_tva_intracommunautaire],
      ['Entreprise forme juridique', :entreprise_forme_juridique],
      ['Entreprise forme juridique code', :entreprise_forme_juridique_code],
      ['Entreprise nom commercial', :entreprise_nom_commercial],
      ['Entreprise raison sociale', :entreprise_raison_sociale],
      ['Entreprise SIRET siège social', :entreprise_siret_siege_social],
      ['Entreprise code effectif entreprise', :entreprise_code_effectif_entreprise],
      ['Entreprise date de création', :entreprise_date_creation],
      ['Entreprise état administratif', :entreprise_etat_administratif],
      ['Entreprise nom', :entreprise_nom],
      ['Entreprise prénom', :entreprise_prenom],
      ['Association RNA', :association_rna],
      ['Association titre', :association_titre],
      ['Association objet', :association_objet],
      ['Association date de création', :association_date_creation],
      ['Association date de déclaration', :association_date_declaration],
      ['Association date de publication', :association_date_publication],
    ]
  end

  def siren
    entreprise_siren
  end

  def geo_adresse
    [numero_voie, type_voie, nom_voie, complement_adresse, code_postal, localite].join(' ')
  end

  def inline_adresse
    # squeeze needed because of space in excess in the data
    [
      "#{numero_voie} #{type_voie} #{nom_voie}",
      complement_adresse,
      "#{code_postal} #{localite}",
    ].compact_blank.join(', ').squeeze(' ')
  end

  def association?
    association_rna.present?
  end

  def entreprise
    Entreprise.new(
      etablissement: self,
      siren: entreprise_siren,
      capital_social: entreprise_capital_social,
      numero_tva_intracommunautaire: entreprise_numero_tva_intracommunautaire,
      forme_juridique: entreprise_forme_juridique,
      forme_juridique_code: entreprise_forme_juridique_code,
      nom_commercial: entreprise_nom_commercial,
      raison_sociale: entreprise_raison_sociale,
      siret_siege_social: entreprise_siret_siege_social,
      code_effectif_entreprise: entreprise_code_effectif_entreprise,
      effectif_mensuel: entreprise_effectif_mensuel,
      effectif_mois: entreprise_effectif_mois,
      effectif_annee: entreprise_effectif_annee,
      effectif_annuel: entreprise_effectif_annuel,
      effectif_annuel_annee: entreprise_effectif_annuel_annee,
      date_creation: entreprise_date_creation,
      etat_administratif: entreprise_etat_administratif,
      nom: entreprise_nom,
      prenom: entreprise_prenom,
      inline_adresse: inline_adresse,
      enseigne: enseigne
    )
  end

  def upload_attestation(url, attestation)
    filename = File.basename(URI.parse(url).path)
    response = Typhoeus.get(url)

    if response.success?
      attestation.attach(
        io: StringIO.new(response.body),
        filename: filename,
        # we don't want to run virus scanner on this file
        metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
      )
    end
  end

  def upload_attestation_sociale(url)
    upload_attestation(url, entreprise_attestation_sociale)
  end

  def upload_attestation_fiscale(url)
    upload_attestation(url, entreprise_attestation_fiscale)
  end

  def entreprise_date_arret_exercice
    entreprise_last_bilan_info_cle("date_arret_exercice")
  end

  def entreprise_resultat_exercice
    entreprise_last_bilan_info_cle("resultat_exercice")
  end

  def entreprise_excedent_brut_exploitation
    entreprise_last_bilan_info_cle("excedent_brut_exploitation")
  end

  def entreprise_fdr_net_global
    entreprise_last_bilan_info_cle("fonds_roulement_net_global")
  end

  def entreprise_besoin_fdr
    entreprise_last_bilan_info_cle("besoin_en_fonds_de_roulement")
  end

  def entreprise_bilans_bdf_to_sheet(format)
    SpreadsheetArchitect.send("to_#{format}".to_sym, bilans_bdf_data)
  end

  def as_degraded_mode?
    adresse.nil? # TOOD: maybe dedicated column or more robust way
  end

  def update_champ_value_json!
    return if champ.nil?

    champ.update!(value_json: champ_value_json)
  end

  def champ_value_json
    address_data = APIGeoService.parse_etablissement_address(self)

    DISPLAYABLE_COLUMNS.keys.each_with_object(address_data) do |attr, hash|
      value = public_send(attr)
      hash[attr.to_sym] = value if value.present?
    end
  end

  def dedicated_siret_siege_social
    if siret != entreprise.siret_siege_social
      entreprise.siret_siege_social
    end
  end

  private

  def bilans_new_keys
    keys = entreprise_bilans_bdf.flat_map(&:keys).uniq
    keys - bilans_headers
  end

  def entreprise_last_bilan_info_cle(key)
    entreprise_bilans_bdf.first[key]
  end

  def bilans_bdf_data
    headers = bilans_headers.concat(bilans_new_keys)
    data = entreprise_bilans_bdf.map do |bilan|
      headers.map { |h| bilan[h] }
    end
    { headers: headers, data: data }
  end

  def dossier_id_for_export
    if dossier_id
      dossier_id.to_s
    elsif champ
      champ.dossier_id.to_s
    end
  end

  def libelle_for_export
    champ&.libelle || 'Dossier'
  end

  def bilans_headers
    [
      "date_arret_exercice", "duree_exercice", "chiffre_affaires_ht", "evolution_chiffre_affaires_ht",
      "valeur_ajoutee_bdf", "evolution_valeur_ajoutee_bdf", "excedent_brut_exploitation",
      "evolution_excedent_brut_exploitation", "resultat_exercice", "evolution_resultat_exercice",
      "capacite_autofinancement", "evolution_capacite_autofinancement", "fonds_roulement_net_global",
      "evolution_fonds_roulement_net_global", "besoin_en_fonds_de_roulement", "evolution_besoin_en_fonds_de_roulement",
      "ratio_fonds_roulement_net_global_sur_besoin_en_fonds_de_roulement",
      "evolution_ratio_fonds_roulement_net_global_sur_besoin_en_fonds_de_roulement", "disponibilites",
      "evolution_disponibilites", "capital_social_inclus_dans_capitaux_propres_et_assimiles",
      "evolution_capital_social_inclus_dans_capitaux_propres_et_assimiles", "capitaux_propres_et_assimiles",
      "evolution_capitaux_propres_et_assimiles", "autres_fonds_propres", "evolution_autres_fonds_propres",
      "total_provisions_pour_risques_et_charges", "evolution_total_provisions_pour_risques_et_charges",
      "dettes1_emprunts_obligataires_et_convertibles", "evolution_dettes1_emprunts_obligataires_et_convertibles",
      "dettes2_autres_emprunts_obligataires", "evolution_dettes2_autres_emprunts_obligataires",
      "dettes3_emprunts_et_dettes_aupres_des_etablissements_de_credit",
      "evolution_dettes3_emprunts_et_dettes_aupres_des_etablissements_de_credit",
      "dettes4_maturite_a_un_an_au_plus", "evolution_dettes4_maturite_a_un_an_au_plus",
      "emprunts_et_dettes_financieres_divers", "evolution_emprunts_et_dettes_financieres_divers",
      "total_dettes_stables", "evolution_total_dettes_stables", "groupes_et_associes",
      "evolution_groupes_et_associes", "total_passif", "evolution_total_passif",
    ]
  end
end
