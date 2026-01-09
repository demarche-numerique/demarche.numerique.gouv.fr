# frozen_string_literal: true

class Dossiers::IdentiteEntrepriseComponent < ApplicationComponent
  attr_reader :etablissement, :dossier

  delegate :pretty_siret, :raison_sociale_or_name, :try_format_date, :try_format_mois_effectif,
    :effectif, :pretty_currency, :sanitize, :pretty_date_exercice, :year_for_bilan, :value_for_bilan_key,
    :pretty_currency_unit, :external_link_attributes, :address_array, to: :helpers

  def initialize(champ: nil, etablissement: nil, avis: nil)
    @etablissement = champ&.etablissement || etablissement
    @dossier = champ&.dossier
    @avis = avis
  end

  def call
    render Dossiers::ExternalChampComponent.new(data:, details:, source:, details_footer:)
  end

  private

  def data
    [
      [label('.siret'), pretty_siret(etablissement.siret), data_to_copy: etablissement.siret],
      [label('.denomination'), raison_sociale_or_name(etablissement)],
      [label('.forme_juridique'), sanitize(etablissement.entreprise.forme_juridique)],
    ]
  end

  def details
    [
      [label('.siret_siege_social'), pretty_siret(etablissement.dedicated_siret_siege_social)],
      [label('.libelle_naf'), etablissement.libelle_naf],
      [label('.code_naf'), etablissement.naf],
      [label('.date_creation'), render(Dossiers::FormattedDateWithBadgeComponent.new(etablissement:))],
      [label('.effectif_mensuel_etablissement', mois: try_format_mois_effectif(etablissement)), etablissement.entreprise_effectif_mensuel],
      [label('.effectif_moyen_annuel_unite_legale', annee: etablissement.entreprise_effectif_annuel_annee), etablissement.entreprise_effectif_annuel],
      [label('.effectif_organisation_insee'), effectif(etablissement)],
      [label('.numero_tva_intracommunautaire'), etablissement.entreprise.numero_tva_intracommunautaire],
      *address_array(etablissement),
      [label('.capital_social'), pretty_currency(etablissement.entreprise.capital_social)],
      [label('.chiffre_affaires'), chiffre_affaires],
      [label('.resultat_exercice'), extract_from_bilans('resultat_exercice')],
      [label('.excedent_brut_exploitation'), extract_from_bilans('excedent_brut_exploitation')],
      [label('.fonds_roulement_net_global'), extract_from_bilans('fonds_roulement_net_global')],
      [label('.besoin_fonds_roulement'), extract_from_bilans('besoin_en_fonds_de_roulement')],
      [label('.chiffres_financiers_cles', monnaie: pretty_currency_unit(etablissement.entreprise_bilans_bdf_monnaie)), chiffre_cles_bdf, copy: false],
      [label('.attestation_sociale'), link_attestation_sociale, copy: false],
      [label('.attestation_fiscale'), link_attestation_fiscale, copy: false],
      [label('.numero_rna'), etablissement.association_rna],
      [label('.titre'), etablissement.association_titre],
      [label('.objet'), etablissement.association_objet],
      [label('.date_creation_association'), try_format_date(etablissement.association_date_creation)],
      [label('.date_publication'), try_format_date(etablissement.association_date_publication)],
      [label('.date_declaration'), try_format_date(etablissement.association_date_declaration)],
    ]
  end

  def chiffre_cles_bdf
    return if @dossier.nil? || @avis.nil?
    csv, xlsx, ods = ['csv', 'xlsx', 'ods'].map { link_to("au format #{it}", bilan_bdf(it)) }

    safe_join(["Les consulter ", csv, ", ", xlsx, " ou ", ods])
  end

  def link_attestation_sociale
    if etablissement.entreprise_attestation_sociale.attached?
      link_to("Consulter l’attestation", url_for(etablissement.entreprise_attestation_sociale), **external_link_attributes)
    end
  end

  def link_attestation_fiscale
    if etablissement.entreprise_attestation_fiscale.attached?
      link_to("Consulter l’attestation", url_for(etablissement.entreprise_attestation_fiscale), **external_link_attributes)
    end
  end

  def bilan_bdf(format)
    if @avis.present?
      bilans_bdf_instructeur_avis_path(@avis, format:)
    else
      dossier_id, procedure_id = @dossier.id, @dossier.procedure.id
      bilans_bdf_instructeur_dossier_path(procedure_id:, dossier_id:, format:)
    end
  end

  def source
    "INSEE, Infogreffe, URSSAF …"
  end

  def chiffre_affaires
    etablissement.exercices
      .map { [it.date_fin_exercice.year, pretty_currency(it.ca)] }
      .then { to_dl(it) }
  end

  def to_dl(array)
    return nil if array.blank?

    dt_dds = array
      .map { |label, value| tag.dt(label, class: 'inline') + tag.dd(value, class: 'inline') }
    dt_dds.last&.concat(tag.span('data-copy-message-placeholder': true))

    tag.dl do
      dt_dds.map do |el|
        tag.div(el)
      end.then { safe_join(it) }
    end
  end

  def extract_from_bilans(key)
    return nil if etablissement.entreprise_bilans_bdf.blank?

    etablissement.entreprise_bilans_bdf.map do |bilan|
      [
        pretty_date_exercice(year_for_bilan(bilan)),
        pretty_currency(
          value_for_bilan_key(bilan, key),
          unit: pretty_currency_unit(etablissement.entreprise_bilans_bdf_monnaie)
        ),
      ]
    end.then { |it| to_dl(it) }
  end

  def details_footer = Dossiers::AnnuaireEntrepriseLinkComponent.new(siret: etablissement.siret)

  def label(k, opt = {}) = etablissement.class.human_attribute_name(k, opt)
end
