# frozen_string_literal: true

FactoryBot.define do
  factory :dossier_pending_response do
    dossier { association :dossier }
    commentaire { association :commentaire, dossier:, instructeur: association(:instructeur) }
    responded_at { nil }

    trait :responded do
      responded_at { Time.current }
    end
  end
end
