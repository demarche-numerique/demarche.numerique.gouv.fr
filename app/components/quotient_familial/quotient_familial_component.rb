# frozen_string_literal: true

class QuotientFamilial::QuotientFamilialComponent < ApplicationComponent
  attr_reader :qf_data

  def initialize(qf_data:, with_header: false)
    @qf_data = qf_data
    @with_header = with_header
  end

  def source
    tag.acronym("API Quotient familial CAF & MSA")
  end

  def data
    qf = qf_data["quotient_familial"]
    allocataires = qf_data["allocataires"]
    enfants = qf_data["enfants"]
    adresse = qf_data["adresse"]

    rows = []

    if qf.present?
      rows << ["Quotient familial #{qf['fournisseur']}", qf_values(qf)]
    end

    allocataires&.each_with_index do |allocataire, index|
      suffix = allocataires.size > 1 ? " #{index + 1}" : ""

      rows << ["Allocataire#{suffix}", individual_values(allocataire)]
    end

    enfants&.each_with_index do |enfant, index|
      suffix = enfants.size > 1 ? " #{index + 1}" : ""

      rows << ["Enfant#{suffix}", individual_values(enfant)]
    end

    if adresse.present?
      rows << ["Adresse de la famille", adresse_values(adresse)]
    end

    rows
  end

  private

  def qf_values(qf)
    [
      ["Valeur :", number_with_delimiter(qf["valeur"], delimiter: " ")],
      ["Période effective :", I18n.l(Date.new(qf["annee"].to_i, qf["mois"].to_i, 1), format: "%m/%Y")],
    ]
  end

  def individual_values(individual)
    [
      ["Nom de naissance :", individual["nom_naissance"]],
      ["Nom d'usage :", individual["nom_usage"]],
      ["Prénoms :", individual["prenoms"]],
      ["Date de naissance :", I18n.l(Date.parse(individual["date_naissance"]), format: :short)],
      ["Sexe :", individual["sexe"]],
    ].reject { |_, v| v.nil? }
  end

  def adresse_values(adresse)
    [
      ["Identité du destinataire :", adresse["destinataire"]],
      ["Adresse :", format_adresse(adresse)],
    ]
  end

  def format_adresse(adresse)
    [
      adresse["complement_information"],
      adresse["complement_information_geographique"],
      adresse["lieu_dit"],
      adresse["numero_libelle_voie"],
      adresse["code_postal_ville"],
      adresse["pays"],
    ].compact.join(", ")
  end
end
