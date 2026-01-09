# frozen_string_literal: true

module Types
  class ServiceType < Types::BaseObject
    class TypeOrganisme < Types::BaseEnum
      Service.type_organismes.each do |symbol_name, string_name|
        value(string_name, I18n.t(symbol_name, scope: [:type_organisme]), value: symbol_name)
      end
    end

    global_id_field :id

    field :nom, String, "nom du service qui met en oeuvre la démarche", null: false
    field :type_organisme, TypeOrganisme, "type d’organisme qui met en oeuvre la démarche", null: false
    field :organisme, String, "nom de l’organisme qui met en oeuvre la démarche", null: false
    field :siret, String, "n° siret du service qui met en oeuvre la démarche", null: true
  end
end
