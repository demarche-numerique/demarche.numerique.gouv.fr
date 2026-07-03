# frozen_string_literal: true

module Mutations
  class DossierModifierAnnotations < Mutations::BaseMutation
    description "Modifier les annotations privées."

    class AnnotationValueInput < Types::BaseInputObject
      one_of
      argument :text, String, "Modifier la valeur d’un champ texte", required: false
      argument :textarea, String, "Modifier la valeur d’un champ texte long", required: false
      argument :email, String, "Modifier la valeur d’un champ adresse électronique", required: false
      argument :checkbox, Boolean, "Modifier la valeur d’un champ case à cocher", required: false
      argument :yes_no, Boolean, "Modifier la valeur d’un champ Oui/Non", required: false
      argument :date, GraphQL::Types::ISO8601Date, "Modifier la valeur d’un champ date", required: false
      argument :datetime, GraphQL::Types::ISO8601DateTime, "Modifier la valeur d’un champ date et heure", required: false
      argument :integer_number, Int, "Modifier la valeur d’un champ nombre entier", required: false
      argument :decimal_number, Float, "Modifier la valeur d’un champ nombre décimal", required: false
      argument :drop_down_list, String, "Modifier la sélection d’un champ choix simple", required: false
      argument :multiple_drop_down_list, [String], "Modifier la sélection d’un champ choix multiple", required: false
      argument :dossier_link, String, "Modifier la valeur d'un champ lien vers un dossier", required: false
      argument :repetition, Int, "Ajouter des repetitions à un champ répétable", required: false
    end

    class AnnotationInput < Types::BaseInputObject
      argument :id, ID, "Annotation ID", required: true
      argument :value, AnnotationValueInput, "Valeur de l’annotation.", required: true
    end

    argument :dossier_id, ID, "Dossier ID", required: true, loads: Types::DossierType
    argument :instructeur_id, ID, "Instructeur qui demande la modification.", required: true, loads: Types::ProfileType
    argument :annotations, [AnnotationInput], "Annotations à modifier", required: true

    field :annotations, [Types::ChampType], null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(dossier:, instructeur:, annotations:)
      update_annotations(dossier, annotations)
    end

    def authorized?(dossier:, instructeur:, **args)
      dossier.with_revision
      dossier_authorized_for?(dossier, instructeur)
    end

    private

    def update_annotations(dossier, annotations)
      errors = []
      annotations, invalid_annotations = annotations
        .filter_map do
          annotation = find_annotation(dossier, _1)
          case annotation
          when :not_found
            errors << "L‘annotation \"#{_1.id}\" n’existe pas"
            nil
          when :wrong_type
            errors << "L‘annotation \"#{_1.id}\" n’est pas de type attendu"
            nil
          else
            annotation
          end
        end
        .partition { _1.repetition? || (_1.validate(:champ_value) && _1.save) }
      errors += invalid_annotations.flat_map { _1.errors.full_messages }

      { annotations:, errors: errors.presence }
    end

    def find_annotation(dossier, annotation)
      stable_id, row_id = ChampData.decode_typed_id(annotation.id)
      type_de_champ = dossier.find_type_de_champ_by_stable_id(stable_id, :private)
      return :not_found if type_de_champ.nil? || !type_de_champ.type_champ.in?(accepted_types)

      value = annotation.value.public_send(type_de_champ.type_champ.to_sym)
      return :wrong_type if value.nil?

      if type_de_champ.repetition?
        value.times do
          dossier.repetition_add_row(type_de_champ, updated_by: current_administrateur.email)
        end
        return dossier.project_champ(type_de_champ)
      end

      champ = dossier.champ_for_update(type_de_champ, row_id:, updated_by: current_administrateur.email)
      case champ.type_champ
      when 'datetime'
        champ.value = value.iso8601(0)
      when 'multiple_drop_down_list'
        champ.value = value
      else
        champ.value = value.to_s
      end
      champ
    end

    def accepted_types
      [
        TypeDeChamp.type_champs.fetch(:text),
        TypeDeChamp.type_champs.fetch(:textarea),
        TypeDeChamp.type_champs.fetch(:email),
        TypeDeChamp.type_champs.fetch(:checkbox),
        TypeDeChamp.type_champs.fetch(:yes_no),
        TypeDeChamp.type_champs.fetch(:date),
        TypeDeChamp.type_champs.fetch(:datetime),
        TypeDeChamp.type_champs.fetch(:integer_number),
        TypeDeChamp.type_champs.fetch(:decimal_number),
        TypeDeChamp.type_champs.fetch(:drop_down_list),
        TypeDeChamp.type_champs.fetch(:multiple_drop_down_list),
        TypeDeChamp.type_champs.fetch(:dossier_link),
        TypeDeChamp.type_champs.fetch(:repetition),
      ]
    end
  end
end
