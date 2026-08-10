# frozen_string_literal: true

RSpec.describe TypesDeChamp::ConditionValidator do
  include Logic

  let(:procedure) { create(:procedure, types_de_champ_public:) }

  subject do
    procedure.validate(:public_types_de_champ_editor)
    procedure.errors.messages_for(:draft_public_types_de_champ)
  end

  let(:invalid_condition_message) do
    I18n.t('activerecord.errors.models.procedure.attributes.draft_public_types_de_champ.invalid_condition')
  end

  context 'when a child references an upper sibling in the same repetition' do
    let(:types_de_champ_public) do
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
    let(:types_de_champ_public) do
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
end
