# frozen_string_literal: true

module Types
  class ProfileType < Types::BaseObject
    description "Profil d’un usager connecté (déposant un dossier, instruisant un dossier...)"

    global_id_field :id
    field :email, String, "Adresse électronique de l’usager", null: false
  end
end
