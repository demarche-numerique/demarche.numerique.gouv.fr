# frozen_string_literal: true

RSpec.describe Mutations::DossierModifierAnnotations, type: :graphql do
  let(:admin) { administrateurs.default }
  let(:procedure) { create(:procedure, :published, :for_individual, types_de_champ_private:, administrateurs: [admin]) }
  let(:types_de_champ_private) do
    [
      {
        type: :repetition,
        children: [
          { libelle: 'Nom' },
          { type: :integer_number, libelle: 'Age' },
          { type: :decimal_number, libelle: 'Montant' },
        ],
      },
      { type: :decimal_number, libelle: 'Montant' },
      {},
      { type: :email },
    ]
  end
  let(:dossiers) { [] }
  let(:instructeur) { create(:instructeur, followed_dossiers: dossiers) }
  let(:champs_private) { dossier.root_champs_private }

  let(:query) { '' }
  let(:context) { { administrateur_id: admin.id, procedure_ids: admin.procedure_ids, write_access: true } }
  let(:variables) { {} }

  subject { API::V2::Schema.execute(query, variables: variables, context: context) }

  let(:data) { subject['data'].deep_symbolize_keys }
  let(:errors) { subject['errors'] }

  before do
    instructeur.assign_to_procedure(procedure)
  end

  describe 'dossierModifierAnnotationAjouterLigne' do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_annotations, procedure: procedure) }
    let(:dossiers) { [dossier] }

    let(:annotation) { champs_private.find(&:repetition?) }
    let(:query) { DOSSIER_MODIFIER_ANNOTATION_AJOUTER_LIGNE_MUTATION }
    let(:variables) do
      {
        input: {
          dossierId: dossier.to_typed_id,
          annotationId: annotation.to_typed_id,
          instructeurId: instructeur.to_typed_id,
        },
      }
    end

    context 'with invalid champ' do
      let(:annotation) { champs_private.last }

      it 'return error' do
        expect(data).to eq(dossierModifierAnnotationAjouterLigne: {
          annotation: nil,
          errors: [{ message: "L’annotation \"#{annotation.to_typed_id}\" n’existe pas" }],
        })
      end
    end

    it 'add row' do
      expect(annotation.row_ids.size).to eq(2)
      expect(data).to eq(dossierModifierAnnotationAjouterLigne: {
        annotation: {
          id: annotation.to_typed_id,
        },
        errors: nil,
      })
      dossier.reload
      expect(annotation.row_ids.size).to eq(3)
    end
  end

  describe 'dossierModifierAnnotationText' do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_annotations, procedure: procedure) }
    let(:dossiers) { [dossier] }

    let(:annotation) { champs_private.find(&:text?) }
    let(:query) { DOSSIER_MODIFIER_ANNOTATION_TEXT_MUTATION }
    let(:variables) do
      {
        input: {
          dossierId: dossier.to_typed_id,
          annotationId: annotation.to_typed_id,
          instructeurId: instructeur.to_typed_id,
          value: 'Hello world',
        },
      }
    end

    it 'update champ' do
      expect(data).to eq(dossierModifierAnnotationText: {
        annotation: {
          id: annotation.to_typed_id,
        },
        errors: nil,
      })
      expect(annotation.reload.value).to eq('Hello world')
    end

    context 'with invalid champ' do
      let(:annotation) { champs_private.find(&:repetition?) }

      it 'return error' do
        expect(data).to eq(dossierModifierAnnotationText: {
          annotation: nil,
          errors: [{ message: "L’annotation \"#{annotation.to_typed_id}\" n’existe pas" }],
        })
      end
    end

    context 'with rows' do
      let(:annotation) { champs_private.find(&:repetition?).rows.first.champs.first }
      let(:other_annotation) { champs_private.find(&:repetition?).rows.second.champs.first }

      it 'update champ' do
        expect(data).to eq(dossierModifierAnnotationText: {
          annotation: {
            id: annotation.to_typed_id,
          },
          errors: nil,
        })
        expect(annotation.reload.value).to eq('Hello world')
        expect(other_annotation.reload.value).not_to eq('Hello world')
      end
    end
  end

  describe 'dossierModifierAnnotationDecimalNumber' do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_annotations, procedure: procedure) }
    let(:dossiers) { [dossier] }

    let(:annotation) { champs_private.find(&:decimal_number?) }
    let(:query) { DOSSIER_MODIFIER_ANNOTATION_DECIMAL_MUTATION }
    let(:variables) do
      {
        input: {
          dossierId: dossier.to_typed_id,
          annotationId: annotation.to_typed_id,
          instructeurId: instructeur.to_typed_id,
          value: 12.34,
        },
      }
    end

    it 'update champ' do
      expect(data).to eq(dossierModifierAnnotationDecimalNumber: {
        annotation: {
          id: annotation.to_typed_id,
        },
        errors: nil,
      })
      expect(annotation.reload.value).to eq('12.34')
    end

    context 'with invalid champ' do
      let(:annotation) { champs_private.first }

      it 'return error' do
        expect(data).to eq(dossierModifierAnnotationDecimalNumber: {
          annotation: nil,
          errors: [{ message: "L’annotation \"#{annotation.to_typed_id}\" n’existe pas" }],
        })
      end
    end

    context 'with rows' do
      let(:annotation) { champs_private.find(&:repetition?).rows.first.champs.find(&:decimal_number?) }
      let(:other_annotation) { champs_private.find(&:repetition?).rows.second.champs.find(&:decimal_number?) }

      it 'update champ' do
        expect(data).to eq(dossierModifierAnnotationDecimalNumber: {
          annotation: {
            id: annotation.to_typed_id,
          },
          errors: nil,
        })
        expect(annotation.reload.value).to eq('12.34')
        expect(other_annotation.reload.value).not_to eq('12.34')
      end
    end
  end

  describe 'dossierModifierAnnotations' do
    let(:dossier) { create(:dossier, :en_construction, :with_populated_annotations, procedure: procedure) }
    let(:dossiers) { [dossier] }

    let(:annotation) { champs_private.find(&:decimal_number?) }
    let(:query) { DOSSIER_MODIFIER_ANNOTATIONS_MUTATION }
    let(:variables) do
      {
        input: {
          dossierId: dossier.to_typed_id,
          instructeurId: instructeur.to_typed_id,
          annotations:,
        },
      }
    end
    let(:annotations) { [{ id: annotation.to_typed_id, value: }] }
    let(:value) { { decimalNumber: 12.34 } }

    it 'update annotation' do
      expect(data).to eq(dossierModifierAnnotations: {
        annotations: [{ id: annotation.to_typed_id }],
        errors: nil,
      })
      expect(annotation.reload.value).to eq('12.34')
    end

    context 'with not found annotation' do
      let(:annotation_id) { GraphQL::Schema::UniqueWithinType.encode('Champ', Float::INFINITY) }
      let(:annotations) { [{ id: annotation_id, value: { text: '' } }] }

      it 'returns error' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: [],
          errors: [{ message: "L‘annotation \"#{annotation_id}\" n’existe pas" }],
        })
      end
    end

    context 'with wrong type annotation' do
      let(:value) { { text: "hello" } }

      it 'returns error' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: [],
          errors: [{ message: "L‘annotation \"#{annotation.to_typed_id}\" n’est pas de type attendu" }],
        })
      end
    end

    context 'with invalid annotation' do
      let(:annotation) { champs_private.find(&:email?) }
      let(:value) { { email: "test" } }

      it 'returns error' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: [],
          errors: [{ message: "est invalide. Saisissez une adresse électronique valide. Exemple : adresse@mail.com" }],
        })
      end
    end

    context 'with rows' do
      let(:annotation) { champs_private.find(&:repetition?).rows.first.champs.find(&:decimal_number?) }
      let(:other_annotation) { champs_private.find(&:repetition?).rows.second.champs.find(&:decimal_number?) }

      it 'update annotation' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: [{ id: annotation.to_typed_id }],
          errors: nil,
        })
        expect(annotation.reload.value).to eq('12.34')
        expect(other_annotation.reload.value).not_to eq('12.34')
      end
    end

    context 'with repetition annotation' do
      let(:annotation) { champs_private.find(&:repetition?) }
      let(:value) { { repetition: 2 } }

      it 'add rows' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: [{ id: annotation.to_typed_id }],
          errors: nil,
        })
        expect(annotation.rows.size).to eq(2)
      end
    end

    context 'with dossier_link annotation and invalid dossier id' do
      let(:types_de_champ_private) { [{ type: :dossier_link }] }
      let(:dossier_link_annotation) { champs_private.find(&:dossier_link?) }
      let(:annotations) { [{ id: dossier_link_annotation.to_typed_id, value: { dossierLink: '999999' } }] }

      it 'returns error' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: [],
          errors: [{ message: "Le dossier n’existe pas" }],
        })
      end
    end

    context 'with dossier_link annotation and valid dossier id' do
      let(:types_de_champ_private) { [{ type: :dossier_link }] }
      let(:linked_dossier) { create(:dossier, :en_construction, procedure: procedure) }
      let(:dossier_link_annotation) { champs_private.find(&:dossier_link?) }
      let(:annotations) { [{ id: dossier_link_annotation.to_typed_id, value: { dossierLink: linked_dossier.id.to_s } }] }

      it 'update annotation' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: [{ id: dossier_link_annotation.to_typed_id }],
          errors: nil,
        })
        expect(dossier_link_annotation.reload.value).to eq(linked_dossier.id.to_s)
      end
    end

    context 'with multiple annotations' do
      let(:types_de_champ_private) do
        [
          {},
          { type: :integer_number },
          { type: :decimal_number },
          { type: :checkbox },
          { type: :yes_no },
          { type: :date },
          { type: :datetime },
          { type: :drop_down_list, options: ['option1', 'option2', 'option3'] },
          { type: :multiple_drop_down_list, options: ['option1', 'option2', 'option3'] },
        ]
      end

      let(:text_annotation) { champs_private.find(&:text?) }
      let(:integer_number_annotation) { champs_private.find(&:integer_number?) }
      let(:decimal_number_annotation) { champs_private.find(&:decimal_number?) }
      let(:checkbox_annotation) { champs_private.find(&:checkbox?) }
      let(:yes_no_annotation) { champs_private.find(&:yes_no?) }
      let(:date_annotation) { champs_private.find(&:date?) }
      let(:datetime_annotation) { champs_private.find(&:datetime?) }
      let(:drop_down_list_annotation) { champs_private.find(&:drop_down_list?) }
      let(:multiple_drop_down_list_annotation) { champs_private.find(&:multiple_drop_down_list?) }

      let(:annotations) { [text_annotation, integer_number_annotation, decimal_number_annotation, checkbox_annotation, yes_no_annotation, date_annotation, datetime_annotation, drop_down_list_annotation, multiple_drop_down_list_annotation] }
      let(:types) { [:text, :integerNumber, :decimalNumber, :checkbox, :yesNo, :date, :datetime, :dropDownList, :multipleDropDownList] }
      let(:values) { ['hello', 42, 42.3, true, false, 1.day.from_now.to_date.iso8601, 1.day.from_now.iso8601, 'option1', ['option1', 'option2']] }

      let(:variables) do
        {
          input: {
            dossierId: dossier.to_typed_id,
            instructeurId: instructeur.to_typed_id,
            annotations: annotations.zip(types, values).map { |(annotation, type, value)| { id: annotation.to_typed_id, value: { type => value } } },
          },
        }
      end

      it 'update annotations' do
        expect(data).to eq(dossierModifierAnnotations: {
          annotations: annotations.map { { id: _1.to_typed_id } },
          errors: nil,
        })
        expect(annotations.map { _1.reload.value }).to eq(values.map { _1.class == Array ? _1.to_json : _1.to_s })
      end
    end
  end

  DOSSIER_MODIFIER_ANNOTATION_AJOUTER_LIGNE_MUTATION = <<-GRAPHQL
  mutation($input: DossierModifierAnnotationAjouterLigneInput!) {
    dossierModifierAnnotationAjouterLigne(input: $input) {
      annotation { id }
      errors { message }
    }
  }
  GRAPHQL

  DOSSIER_MODIFIER_ANNOTATION_TEXT_MUTATION = <<-GRAPHQL
  mutation($input: DossierModifierAnnotationTextInput!) {
    dossierModifierAnnotationText(input: $input) {
      annotation { id }
      errors { message }
    }
  }
  GRAPHQL

  DOSSIER_MODIFIER_ANNOTATION_DECIMAL_MUTATION = <<-GRAPHQL
  mutation($input: DossierModifierAnnotationDecimalNumberInput!) {
    dossierModifierAnnotationDecimalNumber(input: $input) {
      annotation { id }
      errors { message }
    }
  }
  GRAPHQL

  DOSSIER_MODIFIER_ANNOTATIONS_MUTATION = <<-GRAPHQL
  mutation($input: DossierModifierAnnotationsInput!) {
    dossierModifierAnnotations(input: $input) {
      annotations { id }
      errors { message }
    }
  }
  GRAPHQL
end
