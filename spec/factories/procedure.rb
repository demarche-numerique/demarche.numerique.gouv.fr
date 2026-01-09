# frozen_string_literal: true

FactoryBot.define do
  sequence(:published_path) { |n| "fake_path#{n}" }

  factory :procedure do
    sequence(:libelle) { |n| "Procedure #{n}" }
    description { "Demande de subvention à l’intention des associations" }
    organisation { "Orga DINUM" }
    cadre_juridique { "un cadre juridique important" }
    published_at { nil }
    duree_conservation_dossiers_dans_ds { 3 }
    max_duree_conservation_dossiers_dans_ds { Procedure::OLD_MAX_DUREE_CONSERVATION }
    estimated_duration_visible { true }
    ask_birthday { false }
    lien_site_web { "https://mon-site.gouv" }
    declarative_with_state { nil }
    sva_svr { {} }
    no_gender { true }
    api_entreprise_token { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }

    groupe_instructeurs { [association(:groupe_instructeur, :default, procedure: instance, strategy: :build)] }
    administrateurs { [administrateur] }

    trait(:new_administrateur) do
      administrateur { create(:administrateur) }
    end

    transient do
      administrateur { Administrateur.find_by(user: { email: "default_admin@admin.com" }) }
      instructeurs { [] }
      types_de_champ_public { [] }
      types_de_champ_private { [] }
      updated_at { nil }
      dossier_submitted_message { nil }
      path { nil }
    end

    after(:build) do |procedure, evaluator|
      procedure.defaut_groupe_instructeur = procedure.groupe_instructeurs.first
      initial_revision = build(:procedure_revision, procedure: procedure, dossier_submitted_message: evaluator.dossier_submitted_message)

      revision_types_de_champ = []

      if evaluator.types_de_champ_public.present?
        if !evaluator.types_de_champ_public.first.is_a?(Hash)
          raise "types_de_champ_public must be an array of hashes"
        end
        revision_types_de_champ += build_types_de_champ(evaluator.types_de_champ_public, revision: initial_revision, scope: :public)
      end

      if evaluator.types_de_champ_private.present?
        if !evaluator.types_de_champ_private.first.is_a?(Hash)
          raise "types_de_champ_private must be an array of hashes"
        end
        revision_types_de_champ += build_types_de_champ(evaluator.types_de_champ_private, revision: initial_revision, scope: :private)
      end

      initial_revision.association(:revision_types_de_champ).target = revision_types_de_champ

      if procedure.brouillon?
        procedure.draft_revision = initial_revision
      else
        procedure.published_revision = initial_revision
        procedure.published_revision.published_at = Time.zone.now
        procedure.draft_revision = build(:procedure_revision, from_original: initial_revision)
      end
    end

    after(:create) do |procedure, evaluator|
      procedure.claim_path!(evaluator.administrateur, evaluator.path)
      evaluator.instructeurs.each { |i| i.assign_to_procedure(procedure) }

      if evaluator.updated_at
        procedure.update_column(:updated_at, evaluator.updated_at)
      end

      procedure.reload
    end

    factory :procedure_with_dossiers do
      transient do
        dossiers_count { 1 }
      end

      after(:create) do |procedure, evaluator|
        user = User.find_by(email: "default_user@user.com")
        create_list(:dossier, evaluator.dossiers_count, procedure: procedure, user: user)
      end
    end

    factory :simple_procedure do
      published

      for_individual { true }
      types_de_champ_public { [{ type: :text, libelle: 'Texte obligatoire', mandatory: true }] }
    end

    trait :with_bulk_message do
      bulk_messages { [create(:bulk_message)] }
    end

    trait :with_logo do
      logo { Rack::Test::UploadedFile.new('spec/fixtures/files/logo_test_procedure.png', 'image/png') }
    end
    trait :expirable do
      procedure_expires_when_termine_enabled { true }
    end
    trait :with_path do
      path { generate(:published_path) }
    end

    trait :with_service do
      service { association :service, administrateur: administrateurs.first }
    end

    trait :with_instructeur do
      after(:create) do |procedure, _evaluator|
        procedure.defaut_groupe_instructeur.instructeurs << build(:instructeur)
      end
    end

    trait :with_zone do
      zones {
        [
          create(:zone, labels:
                 [{ designated_on: Time.zone.now, name: "Ministère 1" }]),
        ]
      }
    end

    trait :routee do
      after(:create) do |procedure, _evaluator|
        create(:groupe_instructeur, label: 'deuxième groupe', procedure: procedure)
      end
    end

    trait :for_individual do
      for_individual { true }
    end

    trait :with_auto_archive do
      auto_archive_on { Time.zone.today + 20 }
    end

    trait :with_type_de_champ do
      types_de_champ_public { [{ type: :text }] }
    end

    trait :with_type_de_champ_private do
      types_de_champ_private { [{ type: :text }] }
    end

    trait :draft do
      aasm_state { :brouillon }
    end

    trait :published do
      aasm_state { :publiee }
      path { generate(:published_path) }
      published_at { Time.zone.now }
      unpublished_at { nil }
      closed_at { nil }
      zones { [association(:zone, strategy: :build)] }
      service { association :service, administrateur: administrateurs.first }
    end

    trait :closed do
      published

      aasm_state { :close }
      published_at { 1.second.ago }
      closed_at { Time.zone.now }
    end

    trait :unpublished do
      published

      aasm_state { :depubliee }
      published_at { 1.second.ago }
      unpublished_at { Time.zone.now }
    end

    trait :discarded do
      hidden_at { Time.zone.now }
    end

    trait :whitelisted do
      after(:build) do |procedure, _evaluator|
        procedure.update(whitelisted_at: Time.zone.now)
      end
    end

    trait :with_notice do
      after(:create) do |procedure, _evaluator|
        procedure.notice.attach(
          io: StringIO.new('Hello World'),
          filename: 'hello.txt',
          # we don't want to run virus scanner on this file
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end
    end

    trait :with_deliberation do
      after(:create) do |procedure, _evaluator|
        procedure.deliberation.attach(
          io: StringIO.new('Hello World'),
          filename: 'hello.txt',
          # we don't want to run virus scanner on this file
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end
    end

    trait :with_all_champs_mandatory do
      after(:build) do |procedure, _evaluator|
        TypeDeChamp.type_champs.map.with_index do |(libelle, type_champ), index|
          if libelle == 'drop_down_list'
            libelle = 'simple_drop_down_list'
          end
          if type_champ == 'repetition'
            build(:type_de_champ_repetition, :with_types_de_champ, procedure: procedure, mandatory: true, libelle: libelle, position: index)
          elsif type_champ == 'referentiel'
            referentiel = build(:api_referentiel, :exact_match)

            build(:type_de_champ_referentiel, procedure: procedure, mandatory: true, libelle: libelle, position: index, referentiel:)
          else
            build(:"type_de_champ_#{type_champ}", procedure: procedure, mandatory: true, libelle: libelle, position: index)
          end
        end
        build(:type_de_champ_drop_down_list, :long, procedure: procedure, mandatory: true, libelle: 'simple_choice_drop_down_list_long', position: TypeDeChamp.type_champs.size)
        build(:type_de_champ_multiple_drop_down_list, :long, procedure: procedure, mandatory: true, libelle: 'multiple_choice_drop_down_list_long', position: TypeDeChamp.type_champs.size + 1)
      end
    end

    trait :with_all_champs do
      after(:build) do |procedure, _evaluator|
        TypeDeChamp.type_champs.map.with_index do |(libelle, type_champ), index|
          if libelle == 'drop_down_list'
            libelle = 'simple_drop_down_list'
          end
          if type_champ == 'repetition'
            build(:type_de_champ_repetition, :with_types_de_champ, procedure: procedure, libelle: libelle, position: index)
          elsif type_champ == 'referentiel'
            referentiel = build(:api_referentiel, :exact_match)

            build(:type_de_champ_referentiel, procedure: procedure, mandatory: true, libelle: libelle, position: index, referentiel:)
          else
            build(:"type_de_champ_#{type_champ}", procedure: procedure, libelle: libelle, position: index)
          end
        end
      end
    end

    # TODO: rewrite with types_de_champ_private
    trait :with_all_annotations do
      after(:build) do |procedure, _evaluator|
        TypeDeChamp.type_champs.map.with_index do |(libelle, type_champ), index|
          if libelle == 'drop_down_list'
            libelle = 'simple_drop_down_list'
          end
          build(:"type_de_champ_#{type_champ}", procedure: procedure, private: true, libelle: libelle, position: index)
        end
      end
    end

    trait :with_dossier_submitted_message do
      after(:build) do |procedure, _evaluator|
        build(:dossier_submitted_message, revisions: [procedure.active_revision])
      end
    end

    trait :sva do
      sva_svr { SVASVRConfiguration.new(decision: :sva).attributes }
    end

    trait :svr do
      sva_svr { SVASVRConfiguration.new(decision: :svr).attributes }
    end

    trait :empty_chorus do
      chorus { ChorusConfiguration.new }
    end

    trait :partial_chorus do
      chorus { ChorusConfiguration.new(centre_de_cout: { a: 1 }) }
    end

    trait :filled_chorus do
      chorus do
        ChorusConfiguration.new(centre_de_cout: { a: 1 },
                                domaine_fonctionnel: { b: 2 },
                                referentiel_de_programmation: { c: 3 })
      end
    end

    trait :accuse_lecture do
      accuse_lecture { true }
    end

    trait :with_labels do
      after(:create) do |procedure, _evaluator|
        procedure.create_generic_labels
      end
    end
  end
end

def build_types_de_champ(types_de_champ, revision:, scope: :public, parent: nil)
  types_de_champ.map do |type_de_champ_attributes|
    referentiel = type_de_champ_attributes.delete(:referentiel)
    if referentiel.present?
      type_de_champ_attributes[:referentiel_id] = referentiel.id
    end
    type_de_champ_attributes
  end.deep_dup.flat_map.with_index do |type_de_champ_attributes, i|
    type = TypeDeChamp.type_champs.fetch(type_de_champ_attributes.delete(:type) || :text).to_sym
    position = type_de_champ_attributes.delete(:position) || i
    children = type_de_champ_attributes.delete(:children)
    options = type_de_champ_attributes.delete(:options)
    layers = type_de_champ_attributes.delete(:layers)

    if !options.nil?
      if type == :drop_down_list
        type_de_champ_attributes[:drop_down_other] = options.delete(:other).present?
      end

      if type.in?([:drop_down_list, :multiple_drop_down_list, :linked_drop_down_list])
        type_de_champ_attributes[:drop_down_options] = options
      end
    end

    if type == :linked_drop_down_list
      type_de_champ_attributes[:drop_down_secondary_libelle] = type_de_champ_attributes.delete(:secondary_libelle)
      type_de_champ_attributes[:drop_down_secondary_description] = type_de_champ_attributes.delete(:secondary_description)
    end

    if type == :carte && layers.present?
      type_de_champ_attributes[:editable_options] = layers.index_with { '1' }
    end

    if type == :header_section
      type_de_champ_attributes[:header_section_level] = type_de_champ_attributes.delete(:level)
    end

    type_de_champ = if scope == :private
      build(:"type_de_champ_#{type}", :private, no_coordinate: true, **type_de_champ_attributes)
    else
      build(:"type_de_champ_#{type}", no_coordinate: true, **type_de_champ_attributes)
    end
    coordinate = build(:procedure_revision_type_de_champ,
      revision:,
      type_de_champ:,
      position:,
      parent:)

    if type_de_champ.repetition? && children.present?
      [coordinate] + build_types_de_champ(children, revision:, scope:, parent: coordinate)
    else
      coordinate
    end
  end
end
