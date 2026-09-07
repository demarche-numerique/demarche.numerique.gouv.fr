# frozen_string_literal: true

class APIEntreprise::Sirene
  include Dry::Monads[:result]

  def self.fetch_etablissement(siret, procedure_id) = new(siret, procedure_id).fetch_etablissement

  def initialize(siret, procedure_id)
    @siret = siret
    @procedure_id = procedure_id
  end

  def fetch_etablissement
    APIEntreprise::API.new(@procedure_id).etablissement(@siret)
      .fmap { extract_etablissement(it[:data]) }
  rescue StandardError => e
    # The API answered, we could not read it. Without this the exception escapes
    # through the state machine callback and strands the champ in fetching.
    Sentry.capture_exception(e)

    Failure(type: :unreadable_payload, code: 200)
  end

  private

  def extract_etablissement(raw_data)
    params = extract_etablissement_params(raw_data).merge(extract_enterprise_params(raw_data[:unite_legale]))

    # The API fills a field it cannot serve with that sentence: leave it empty
    # rather than exporting it as if it were the company's name.
    Etablissement.new(params.reject { |_, value| value == APIEntreprise::Adapter::UNAVAILABLE })
  end

  def extract_etablissement_params(raw_data)
    params = raw_data.slice(:adresse, :siret, :siege_social, :enseigne, :diffusable_commercialement)

    params[:naf_2025] = raw_data.dig(:activite_principale, :code)
    params[:libelle_naf_2025] = raw_data.dig(:activite_principale, :libelle)
    params[:naf] = raw_data.dig(:activite_principale_naf_rev2, :code)
    params[:libelle_naf] = raw_data.dig(:activite_principale_naf_rev2, :libelle)

    adresse_line = raw_data[:adresse][:acheminement_postal].slice(:l1, :l2, :l3, :l4, :l5, :l6, :l7).values.compact.join("\r\n")
    params.merge!(params[:adresse].slice(:numero_voie, :type_voie, :complement_adresse, :code_postal))
    params[:nom_voie] = raw_data[:adresse][:libelle_voie]
    params[:code_insee_localite] = raw_data[:adresse][:code_commune]
    if raw_data[:adresse][:libelle_pays_etranger].present?
      params[:localite] = raw_data[:adresse][:libelle_commune_etranger]
      params[:nom_pays] = raw_data[:adresse][:libelle_pays_etranger]
    else
      params[:localite] = raw_data[:adresse][:libelle_commune]
    end
    params[:adresse] = adresse_line

    params
  end

  def extract_enterprise_params(unite_legale)
    return {} if unite_legale.nil?

    params = {}
    params[:siren] = unite_legale[:siren]
    params[:siret_siege_social] = unite_legale[:siret_siege_social]
    params[:date_creation] = Time.zone.at(unite_legale[:date_creation]).to_datetime if unite_legale[:date_creation].present?
    params[:etat_administratif] = map_etat_administratif(unite_legale[:etat_administratif])
    params[:forme_juridique] = unite_legale.dig(:forme_juridique, :libelle)
    params[:forme_juridique_code] = unite_legale.dig(:forme_juridique, :code)
    params[:raison_sociale] = unite_legale.dig(:personne_morale_attributs, :raison_sociale)

    if unite_legale[:personne_physique_attributs].present?
      params[:nom] = build_nom(unite_legale[:personne_physique_attributs])
      params[:prenom] = unite_legale.dig(:personne_physique_attributs, :prenom_usuel)
    end

    params[:code_effectif_entreprise] = unite_legale.dig(:tranche_effectif_salarie, :code)

    params.transform_keys { |k| :"entreprise_#{k}" }
  end

  def build_nom(attrs)
    nom_usage = attrs[:nom_usage]&.strip
    nom_naissance = attrs[:nom_naissance]&.strip
    return nom_usage if nom_naissance.blank? || nom_usage == nom_naissance
    return nom_naissance if nom_usage.blank?
    "#{nom_usage} (#{nom_naissance})"
  end

  def map_etat_administratif(raw_value)
    case raw_value
    when 'A' then 'actif'
    when 'F', 'C' then 'fermé'
    end
  end
end
