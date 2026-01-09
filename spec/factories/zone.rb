# frozen_string_literal: true

FactoryBot.define do
  factory :zone do
    sequence(:acronym) { |n| "MA#{n}" }
    tchap_hs { ['agent.educpop.tchap.gouv.fr'] }
    transient do
      labels { [{ designated_on: '1981-05-08', name: "Ministère de l’Education Populaire" }] }
    end

    after(:build) do |zone, evaluator|
      evaluator.labels.each do |label|
        zone.labels.build(designated_on: label[:designated_on], name: label[:name])
      end
    end
  end
end
