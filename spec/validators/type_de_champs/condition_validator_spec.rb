# frozen_string_literal: true

RSpec.describe TypeDeChamps::ConditionValidator do
  include Logic

  let(:procedure) { create(:procedure, public_type_de_champs:) }

  subject do
    procedure.validate(:public_type_de_champs_editor)
    procedure.errors.messages_for(:public_draft_type_de_champs)
  end

  let(:invalid_condition_message) do
    I18n.t('activerecord.errors.models.procedure.attributes.public_draft_type_de_champs.invalid_condition')
  end

  context 'when a child references an upper sibling in the same repetition' do
    let(:public_type_de_champs) do
      [
        {
          type: :repetition, libelle: 'Bloc', stable_id: 1, children: [
            { type: :yes_no, libelle: 'Booléen', stable_id: 2 },
            { type: :text, libelle: 'Conditionnel', stable_id: 3, condition: ds_eq(champ_value(2), constant(true)) },
          ],
        },
      ]
    end

    it 'is valid' do
      expect(subject).not_to include(invalid_condition_message)
    end
  end

  context 'when a repetition itself has an invalid condition' do
    let(:public_type_de_champs) do
      [
        {
          type: :repetition, libelle: 'Bloc', stable_id: 1,
          condition: ds_eq(champ_value(2), constant(true)),
          children: [{ type: :text, libelle: 'Enfant', stable_id: 10 }],
        },
        { type: :yes_no, libelle: 'Booléen plus bas', stable_id: 2 },
      ]
    end

    it 'adds an error on the repetition condition' do
      expect(subject).to include(invalid_condition_message)
    end
  end

  context 'when a condition is contradictory' do
    let(:public_type_de_champs) do
      [
        { type: :integer_number, libelle: 'Nombre', stable_id: 1 },
        { type: :text, libelle: 'Conditionnel', stable_id: 2, condition: ds_and([greater_than(champ_value(1), constant(3)), less_than(champ_value(1), constant(2))]) },
      ]
    end

    it 'adds an error on the condition' do
      expect(subject).to include(invalid_condition_message)
    end
  end

  context 'when a condition targets a champ that is never displayed in that case' do
    let(:public_type_de_champs) do
      [
        { type: :integer_number, libelle: 'Nombre', stable_id: 1 },
        { type: :yes_no, libelle: 'Caché', stable_id: 2, condition: greater_than(champ_value(1), constant(10)) },
        { type: :text, libelle: 'Conditionnel', stable_id: 3, condition: ds_and([ds_eq(champ_value(2), constant(true)), less_than(champ_value(1), constant(5))]) },
      ]
    end

    it 'adds an error on the condition' do
      expect(subject).to include(invalid_condition_message)
    end
  end
end
