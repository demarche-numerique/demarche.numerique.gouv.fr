# frozen_string_literal: true

# Résout la source de préremplissage de l'identité d'un dossier (nom, prénom,
# éventuellement civilité) à partir du fournisseur d'identité de l'usager.
#
# Deux entrées : le dossier et un booléen `pro_connect` (la session courante
# est-elle ProConnectée). Consommé par le composant du formulaire identité, le
# contrôleur et DossierFranceConnectPrefillConcern, qui s'accordent ainsi par
# construction.
class IdentityPrefillSource
  attr_reader :dossier

  def initialize(dossier:, pro_connect: false)
    @dossier = dossier
    @pro_connect = pro_connect
  end

  # :pro_connect | :france_connect | nil — la session courante prime, avec repli
  # sur FranceConnect si l'identité ProConnect est incomplète.
  def name
    @name ||= if @pro_connect && pro_connect_identity_complete?
      :pro_connect
    elsif dossier.identity_from_fc?
      :france_connect
    end
  end

  def none? = name.nil?
  def france_connect? = name == :france_connect
  def pro_connect? = name == :pro_connect

  # Champs de `individual` à verrouiller ET à stripper côté serveur.
  # ProConnect ne fournit pas de civilité -> le gender reste éditable.
  #
  # Retourne [] quand for_tiers? : c'est ce qui rend `individual_locked_fields`
  # et `mandataire_locked?` mutuellement exclusifs (le contrôleur peut alors
  # traiter les deux dans des `if` indépendants plutôt qu'en if/elsif ordonné).
  def individual_locked_fields
    return [] if dossier.for_tiers? || none?

    france_connect? ? [:nom, :prenom, :gender] : [:nom, :prenom]
  end

  def individual_field_locked?(field) = individual_locked_fields.include?(field)

  def mandataire_locked? = dossier.for_tiers? && !none?

  def france_connect_information = dossier.user&.france_connect_informations&.first
  def pro_connect_information = dossier.user&.last_pro_connect_information

  private

  def pro_connect_identity_complete?
    info = pro_connect_information
    info.present? && info.given_name.present? && info.usual_name.present?
  end
end
