# frozen_string_literal: true

FactoryBot.define do
  sequence(:stable_id) { |n| 100_000 + n }

  factory :type_de_champ do
    sequence(:libelle) { |n| "Libelle du champ #{n}" }
    sequence(:description) { |n| "description du champ #{n}" }
    type_champ { TypeDeChamp.type_champs.fetch(:text) }
    add_attribute(:private) { false }
    mandatory { !private }

    transient do
      procedure { nil }
      position { nil }
      parent { nil }
      no_coordinate { false }
    end

    after(:build) do |type_de_champ, evaluator|
      if !evaluator.no_coordinate
        revision = evaluator.procedure&.active_revision || build(:procedure_revision)
        evaluator.procedure&.save

        revision.revision_types_de_champ << build(:procedure_revision_type_de_champ,
          position: evaluator.position || 0,
          revision: revision,
          type_de_champ: type_de_champ,
          parent: evaluator.parent)

        revision.save
      end
    end

    trait :private do
      add_attribute(:private) { true }
      sequence(:libelle) { |n| "Libelle champ privé #{n}" }
      sequence(:description) { |n| "description du champ privé #{n}" }
    end

    factory :type_de_champ_text do
      type_champ { TypeDeChamp.type_champs.fetch(:text) }
    end
    factory :type_de_champ_textarea do
      type_champ { TypeDeChamp.type_champs.fetch(:textarea) }
    end
    factory :type_de_champ_number do
      type_champ { TypeDeChamp.type_champs.fetch(:number) }
    end
    factory :type_de_champ_decimal_number do
      type_champ { TypeDeChamp.type_champs.fetch(:decimal_number) }
    end
    factory :type_de_champ_integer_number do
      type_champ { TypeDeChamp.type_champs.fetch(:integer_number) }
    end
    factory :type_de_champ_checkbox do
      type_champ { TypeDeChamp.type_champs.fetch(:checkbox) }
    end
    factory :type_de_champ_civilite do
      type_champ { TypeDeChamp.type_champs.fetch(:civilite) }
    end
    factory :type_de_champ_email do
      type_champ { TypeDeChamp.type_champs.fetch(:email) }
    end
    factory :type_de_champ_phone do
      type_champ { TypeDeChamp.type_champs.fetch(:phone) }
    end
    factory :type_de_champ_address do
      type_champ { TypeDeChamp.type_champs.fetch(:address) }
    end
    factory :type_de_champ_yes_no do
      libelle { 'Yes/no' }
      type_champ { TypeDeChamp.type_champs.fetch(:yes_no) }
    end
    factory :type_de_champ_date do
      type_champ { TypeDeChamp.type_champs.fetch(:date) }
    end
    factory :type_de_champ_datetime do
      type_champ { TypeDeChamp.type_champs.fetch(:datetime) }
    end
    factory :type_de_champ_drop_down_list do
      libelle { 'Choix unique' }
      type_champ { TypeDeChamp.type_champs.fetch(:drop_down_list) }
      drop_down_options { ["val1", "val2", "val3"] }
      trait :long do
        drop_down_options { ["alpha", "bravo", "charly", "delta", "echo", "fox-trot", "golf"] }
      end
      trait :with_other do
        drop_down_other { true }
      end
    end
    factory :type_de_champ_multiple_drop_down_list do
      type_champ { TypeDeChamp.type_champs.fetch(:multiple_drop_down_list) }
      drop_down_options { ["val1", "val2", "val3"] }
      trait :long do
        drop_down_options { ["alpha", "bravo", "charly", "delta", "echo", "fox-trot", "golf"] }
      end
    end
    factory :type_de_champ_linked_drop_down_list do
      type_champ { TypeDeChamp.type_champs.fetch(:linked_drop_down_list) }
      drop_down_options { ["--primary--", "secondary"] }
    end
    factory :type_de_champ_formatted do
      type_champ { TypeDeChamp.type_champs.fetch(:formatted) }
      trait :simple do
        options do
          { formatted: "simple" }
        end
      end
      trait :numbers_accepted do
        options do
          {
            formatted_mode: 'simple',
            numbers_accepted: '1',
            letters_accepted: '0',
          }
        end
      end
      trait :advanced do
        options do
          { formatted_mode: "advanced" }
        end
      end
    end
    factory :type_de_champ_pays do
      type_champ { TypeDeChamp.type_champs.fetch(:pays) }
    end
    factory :type_de_champ_regions do
      type_champ { TypeDeChamp.type_champs.fetch(:regions) }
    end
    factory :type_de_champ_departements do
      type_champ { TypeDeChamp.type_champs.fetch(:departements) }
    end
    factory :type_de_champ_communes do
      type_champ { TypeDeChamp.type_champs.fetch(:communes) }
    end
    factory :type_de_champ_header_section do
      type_champ { TypeDeChamp.type_champs.fetch(:header_section) }
    end

    factory :type_de_champ_header_section_level_1 do
      type_champ { TypeDeChamp.type_champs.fetch(:header_section) }
      header_section_level { 1 }
    end
    factory :type_de_champ_header_section_level_2 do
      type_champ { TypeDeChamp.type_champs.fetch(:header_section) }
      header_section_level { 2 }
    end
    factory :type_de_champ_header_section_level_3 do
      type_champ { TypeDeChamp.type_champs.fetch(:header_section) }
      header_section_level { 3 }
    end

    factory :type_de_champ_explication do
      type_champ { TypeDeChamp.type_champs.fetch(:explication) }
    end
    factory :type_de_champ_dossier_link do
      libelle { 'Référence autre dossier' }
      type_champ { TypeDeChamp.type_champs.fetch(:dossier_link) }
    end
    factory :type_de_champ_piece_justificative do
      type_champ { TypeDeChamp.type_champs.fetch(:piece_justificative) }

      after(:build) do |type_de_champ, _evaluator|
        type_de_champ.piece_justificative_template.attach(
          io: StringIO.new("toto"),
          filename: "toto.txt",
          content_type: "text/plain",
          # we don't want to run virus scanner on this file
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end
    end
    factory :type_de_champ_titre_identite do
      type_champ { TypeDeChamp.type_champs.fetch(:titre_identite) }
    end
    factory :type_de_champ_siret do
      type_champ { TypeDeChamp.type_champs.fetch(:siret) }
    end
    factory :type_de_champ_rna do
      type_champ { TypeDeChamp.type_champs.fetch(:rna) }
    end
    factory :type_de_champ_iban do
      type_champ { TypeDeChamp.type_champs.fetch(:iban) }
    end
    factory :type_de_champ_annuaire_education do
      type_champ { TypeDeChamp.type_champs.fetch(:annuaire_education) }
    end
    factory :type_de_champ_cnaf do
      type_champ { TypeDeChamp.type_champs.fetch(:cnaf) }
    end
    factory :type_de_champ_dgfip do
      type_champ { TypeDeChamp.type_champs.fetch(:dgfip) }
    end
    factory :type_de_champ_pole_emploi do
      type_champ { TypeDeChamp.type_champs.fetch(:pole_emploi) }
    end
    factory :type_de_champ_mesri do
      type_champ { TypeDeChamp.type_champs.fetch(:mesri) }
    end
    factory :type_de_champ_carte do
      type_champ { TypeDeChamp.type_champs.fetch(:carte) }
    end
    factory :type_de_champ_epci do
      type_champ { TypeDeChamp.type_champs.fetch(:epci) }
    end
    factory :type_de_champ_engagement_juridique do
      type_champ { TypeDeChamp.type_champs.fetch(:engagement_juridique) }
    end
    factory :type_de_champ_referentiel do
      type_champ { TypeDeChamp.type_champs.fetch(:referentiel) }
    end
    factory :type_de_champ_cojo do
      type_champ { TypeDeChamp.type_champs.fetch(:cojo) }
    end
    factory :type_de_champ_rnf do
      type_champ { TypeDeChamp.type_champs.fetch(:rnf) }
    end
    factory :type_de_champ_quotient_familial do
      type_champ { TypeDeChamp.type_champs.fetch(:quotient_familial) }
    end
    factory :type_de_champ_repetition do
      type_champ { TypeDeChamp.type_champs.fetch(:repetition) }

      transient do
        types_de_champ { [] }
      end

      after(:build) do |type_de_champ_repetition, evaluator|
        evaluator.procedure&.save!
        revision = evaluator.procedure&.active_revision || build(:procedure_revision)
        parent = revision.revision_types_de_champ.find { |rtdc| rtdc.type_de_champ == type_de_champ_repetition }
        types_de_champ = revision.revision_types_de_champ.filter { |rtdc| rtdc.parent == parent }
        position = types_de_champ.size

        evaluator.types_de_champ.each.with_index(position) do |type_de_champ, position|
          revision.revision_types_de_champ << build(:procedure_revision_type_de_champ,
            revision: revision,
            type_de_champ: type_de_champ,
            parent: parent,
            position: position)
        end

        revision.save
      end

      # TODO: drop
      trait :with_types_de_champ do
        after(:build) do |type_de_champ_repetition, evaluator|
          revision = evaluator.procedure.active_revision
          parent = revision.revision_types_de_champ.find { |rtdc| rtdc.type_de_champ == type_de_champ_repetition }

          build(:type_de_champ, procedure: evaluator.procedure, libelle: 'sub type de champ', parent: parent, position: 0)
          build(:type_de_champ, type_champ: TypeDeChamp.type_champs.fetch(:integer_number), procedure: evaluator.procedure, libelle: 'sub type de champ2', parent: parent, position: 1)
        end
      end

      trait :with_region_types_de_champ do
        after(:build) do |type_de_champ_repetition, evaluator|
          revision = evaluator.procedure.active_revision
          parent = revision.revision_types_de_champ.find { |rtdc| rtdc.type_de_champ == type_de_champ_repetition }

          build(:type_de_champ, type_champ: TypeDeChamp.type_champs.fetch(:regions), procedure: evaluator.procedure, libelle: 'region sub_champ', parent: parent, position: 10)
        end
      end
    end
  end
end
