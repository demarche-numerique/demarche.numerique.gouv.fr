# frozen_string_literal: true

FactoryBot.define do
  factory :referentiel do
    factory :csv_referentiel, class: 'Referentiels::CsvReferentiel' do
      name { 'referentiel.csv' }
      headers { ['option', 'calorie (kcal)', 'poids (g)'] }
      trait :with_items do
        after(:create) do |referentiel|
          create(:referentiel_item, referentiel:, data: { row: { 'option' => 'fromage', 'calorie_kcal' => '145', 'poids_g' => '60' } })
          create(:referentiel_item, referentiel:, data: { row: { 'option' => 'dessert', 'calorie_kcal' => '170', 'poids_g' => '70' } })
          create(:referentiel_item, referentiel:, data: { row: { 'option' => 'fruit', 'calorie_kcal' => '100', 'poids_g' => '50' } })
        end
      end
    end

    factory :api_referentiel, class: 'Referentiels::APIReferentiel' do
      trait :autocomplete do # finess
        mode { 'autocomplete' }
        url_tiptap do
          {
            "type" => "doc",
            "content" => [
              {
                "type" => "paragraph",
                "content" => [
                  { "type" => "text", "text" => ENV.fetch('ALLOWED_API_DOMAINS_FROM_FRONTEND').split(',').grep(/tabular-api.data.gouv/).first.to_s + "?finess__contains=" },
                  { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
                ],
              },
            ],
          }
        end
        test_data_tiptap { { "{query}" => "0100026" } }
        json_template do
          {
            "type" => "doc",
              "content" => [
                {
                  "type" => "paragraph",
                  "content" => [
                    { "type" => "mention", "attrs" => { "id" => "$.finess", "label" => "$.finess (010002699)" } },
                    { "text" => " (", "type" => "text" },
                    { "type" => "mention", "attrs" => { "id" => "$.ej_rs", "label" => "$.ej_rs (CENTRE MEDICAL REGINA)" } },
                    { "text" => ")", "type" => "text" },
                  ],
                },
              ],
          }
        end
      end

      trait :exact_match do # rnb
        mode { 'exact_match' }
        url_tiptap do
          {
            "type" => "doc",
            "content" => [
              {
                "type" => "paragraph",
                "content" => [
                  { "type" => "text", "text" => ENV.fetch('ALLOWED_API_DOMAINS_FROM_FRONTEND').split(',').grep(/rnb-api.beta.gouv/).first.to_s + "/api/alpha/buildings/" },
                  { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
                  { "type" => "text", "text" => "/" },
                ],
              },
            ],
          }
        end
        test_data_tiptap { { "{query}" => "PG46YY6YWCX8" } }
      end

      trait :with_exact_match_response do
        last_response do
          {
            status: 200,
            body: JSON.parse(File.read("spec/fixtures/files/api_referentiel_rnb.json")),
          }
        end
      end
      trait :with_autocomplete_response do
        last_response do
          {
            status: 200,
            body: JSON.parse(File.read("spec/fixtures/files/api_referentiel_finess.json")),
          }
        end
      end

      trait :with_authentication_data do
        authentication_method { 'header' }
        authentication_data { { header: 'Authorization', value: 'Bearer token' } }
      end
    end
  end
end
