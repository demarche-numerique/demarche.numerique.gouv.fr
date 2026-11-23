# frozen_string_literal: true

FactoryBot.define do
  factory :procedure_revision do
    transient do
      from_original { nil }
    end

    after(:build) do |revision, evaluator|
      if evaluator.from_original
        from_revision = evaluator.from_original

        revision.procedure = from_revision.procedure
        revision.dossier_submitted_message_id = from_revision.dossier_submitted_message_id
        revision.type_de_champ_tree = from_revision.type_de_champ_tree
      end
    end
  end
end
