# frozen_string_literal: true

FactoryBot.define do
  sequence(:stable_id) { |n| 100_000 + n }

  factory :type_de_champ do
    # STI: attributes must go through new so the subclass is picked from the type attribute.
    initialize_with { TypeDeChamp.new(attributes) }

    sequence(:libelle) { |n| "Libelle du champ #{n}" }
    sequence(:description) { |n| "description du champ #{n}" }
    type { TypesDeChamp::Text.name }
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

        revision.revision_type_de_champs << build(:procedure_revision_type_de_champ,
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
      type { TypesDeChamp::Text.name }
    end
    factory :type_de_champ_textarea do
      type { TypesDeChamp::Textarea.name }
    end
    factory :type_de_champ_number do
      type { TypesDeChamp::Number.name }
    end
    factory :type_de_champ_decimal_number do
      type { TypesDeChamp::DecimalNumber.name }
    end
    factory :type_de_champ_integer_number do
      type { TypesDeChamp::IntegerNumber.name }
    end
    factory :type_de_champ_checkbox do
      type { TypesDeChamp::Checkbox.name }
    end
    factory :type_de_champ_civilite do
      type { TypesDeChamp::Civilite.name }
    end
    factory :type_de_champ_email do
      type { TypesDeChamp::Email.name }
    end
    factory :type_de_champ_phone do
      type { TypesDeChamp::Phone.name }
    end
    factory :type_de_champ_address do
      type { TypesDeChamp::Address.name }
    end
    factory :type_de_champ_yes_no do
      libelle { 'Yes/no' }
      type { TypesDeChamp::YesNo.name }
    end
    factory :type_de_champ_date do
      type { TypesDeChamp::Date.name }
    end
    factory :type_de_champ_datetime do
      type { TypesDeChamp::Datetime.name }
    end
    factory :type_de_champ_drop_down_list do
      libelle { 'Choix unique' }
      type { TypesDeChamp::DropDownList.name }
      drop_down_options { ["val1", "val2", "val3"] }
      trait :long do
        drop_down_options { ["alpha", "bravo", "charly", "delta", "echo", "fox-trot", "golf"] }
      end
      trait :with_other do
        drop_down_other { true }
      end
    end
    factory :type_de_champ_multiple_drop_down_list do
      type { TypesDeChamp::MultipleDropDownList.name }
      drop_down_options { ["val1", "val2", "val3"] }
      trait :long do
        drop_down_options { ["alpha", "bravo", "charly", "delta", "echo", "fox-trot", "golf"] }
      end
    end
    factory :type_de_champ_linked_drop_down_list do
      type { TypesDeChamp::LinkedDropDownList.name }
      drop_down_options { ["--primary--", "secondary"] }
    end
    factory :type_de_champ_formatted do
      type { TypesDeChamp::Formatted.name }
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
      type { TypesDeChamp::Pays.name }
    end
    factory :type_de_champ_regions do
      type { TypesDeChamp::Region.name }
    end
    factory :type_de_champ_departements do
      type { TypesDeChamp::Departement.name }
    end
    factory :type_de_champ_communes do
      type { TypesDeChamp::Commune.name }
    end
    factory :type_de_champ_header_section do
      type { TypesDeChamp::HeaderSection.name }
    end

    factory :type_de_champ_header_section_level_1 do
      type { TypesDeChamp::HeaderSection.name }
      header_section_level { 1 }
    end
    factory :type_de_champ_header_section_level_2 do
      type { TypesDeChamp::HeaderSection.name }
      header_section_level { 2 }
    end
    factory :type_de_champ_header_section_level_3 do
      type { TypesDeChamp::HeaderSection.name }
      header_section_level { 3 }
    end

    factory :type_de_champ_explication do
      type { TypesDeChamp::Explication.name }
    end
    factory :type_de_champ_dossier_link do
      libelle { 'Référence autre dossier' }
      type { TypesDeChamp::DossierLink.name }
    end
    factory :type_de_champ_piece_justificative do
      type { TypesDeChamp::PieceJustificative.name }

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
    factory :type_de_champ_siret do
      type { TypesDeChamp::Siret.name }
    end
    factory :type_de_champ_rna do
      type { TypesDeChamp::RNA.name }
    end
    factory :type_de_champ_iban do
      type { TypesDeChamp::Iban.name }
    end
    factory :type_de_champ_annuaire_education do
      type { TypesDeChamp::AnnuaireEducation.name }
    end
    factory :type_de_champ_carte do
      type { TypesDeChamp::Carte.name }
    end
    factory :type_de_champ_epci do
      type { TypesDeChamp::Epci.name }
    end
    factory :type_de_champ_engagement_juridique do
      type { TypesDeChamp::EngagementJuridique.name }
    end
    factory :type_de_champ_referentiel do
      type { TypesDeChamp::Referentiel.name }
    end
    factory :type_de_champ_pre_rempli do
      type { TypesDeChamp::PreRempli.name }
    end
    factory :type_de_champ_cojo do
      type { TypesDeChamp::COJO.name }
    end
    factory :type_de_champ_rnf do
      type { TypesDeChamp::RNF.name }
    end
    factory :type_de_champ_quotient_familial do
      type { TypesDeChamp::QuotientFamilial.name }
    end
    factory :type_de_champ_etudiant_boursier do
      type { TypesDeChamp::EtudiantBoursier.name }
    end
    factory :type_de_champ_aah do
      type { TypesDeChamp::AAH.name }
    end
    factory :type_de_champ_aeeh do
      type { TypesDeChamp::AEEH.name }
    end
    factory :type_de_champ_ars do
      type { TypesDeChamp::ARS.name }
    end
    factory :type_de_champ_repetition do
      type { TypesDeChamp::Repetition.name }

      transient do
        type_de_champs { [] }
      end

      after(:build) do |type_de_champ_repetition, evaluator|
        evaluator.procedure&.save!
        revision = evaluator.procedure&.active_revision || build(:procedure_revision)
        parent = revision.revision_type_de_champs.find { |rtdc| rtdc.type_de_champ == type_de_champ_repetition }
        type_de_champs = revision.revision_type_de_champs.filter { |rtdc| rtdc.parent == parent }
        position = type_de_champs.size

        evaluator.type_de_champs.each.with_index(position) do |type_de_champ, position|
          revision.revision_type_de_champs << build(:procedure_revision_type_de_champ,
            revision: revision,
            type_de_champ: type_de_champ,
            parent: parent,
            position: position)
        end

        revision.save
      end

      # TODO: drop
      trait :with_type_de_champs do
        after(:build) do |type_de_champ_repetition, evaluator|
          revision = evaluator.procedure.active_revision
          parent = revision.revision_type_de_champs.find { |rtdc| rtdc.type_de_champ == type_de_champ_repetition }

          build(:type_de_champ, procedure: evaluator.procedure, libelle: 'sub type de champ', parent: parent, position: 0)
          build(:type_de_champ, type: TypesDeChamp::IntegerNumber.name, procedure: evaluator.procedure, libelle: 'sub type de champ2', parent: parent, position: 1)
        end
      end

      trait :with_region_type_de_champs do
        after(:build) do |type_de_champ_repetition, evaluator|
          revision = evaluator.procedure.active_revision
          parent = revision.revision_type_de_champs.find { |rtdc| rtdc.type_de_champ == type_de_champ_repetition }

          build(:type_de_champ, type: TypesDeChamp::Region.name, procedure: evaluator.procedure, libelle: 'region sub_champ', parent: parent, position: 10)
        end
      end
    end
  end
end
