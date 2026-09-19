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
    estimated_processing_duration_visible { true }
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
      administrateur { Administrateur.find_by(user: { email: "admin@exemple.fr" }) }
      instructeurs { [] }
      public_type_de_champs { [] }
      private_type_de_champs { [] }
      updated_at { nil }
      dossier_submitted_message { nil }
      path { nil }
    end

    after(:build) do |procedure, evaluator|
      procedure.defaut_groupe_instructeur = procedure.groupe_instructeurs.first
      initial_revision = build(:procedure_revision, procedure: procedure, dossier_submitted_message: evaluator.dossier_submitted_message)

      revision_type_de_champs = []

      if evaluator.public_type_de_champs.present?
        if !evaluator.public_type_de_champs.first.is_a?(Hash)
          raise "public_type_de_champs must be an array of hashes"
        end
        revision_type_de_champs += build_type_de_champs(evaluator.public_type_de_champs, revision: initial_revision, scope: :public)
      end

      if evaluator.private_type_de_champs.present?
        if !evaluator.private_type_de_champs.first.is_a?(Hash)
          raise "private_type_de_champs must be an array of hashes"
        end
        revision_type_de_champs += build_type_de_champs(evaluator.private_type_de_champs, revision: initial_revision, scope: :private)
      end

      initial_revision.association(:revision_type_de_champs).target = revision_type_de_champs

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
        user = User.find_by(email: "usager@exemple.fr")
        create_list(:dossier, evaluator.dossiers_count, procedure: procedure, user: user)
      end
    end

    factory :simple_procedure do
      published

      for_individual { true }
      public_type_de_champs { [{ type: :text, libelle: 'Texte obligatoire', mandatory: true }] }
    end

    trait :with_bulk_message do
      bulk_messages { [create(:bulk_message)] }
    end

    trait :with_logo do
      logo { Rack::Test::UploadedFile.new('spec/fixtures/files/logo_test_procedure.png', 'image/png') }
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
      public_type_de_champs { [{ type: :text }] }
    end

    trait :with_type_de_champ_private do
      private_type_de_champs { [{ type: :text }] }
    end

    trait :with_decimal_number_public do
      public_type_de_champs { [{ type: :decimal_number }] }
    end

    trait :with_decimal_number_private do
      private_type_de_champs { [{ type: :decimal_number }] }
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
      # reuse the seeded zone and service instead of rebuilding them for
      # every published procedure (they only need to be present)
      zones { [Oaken::Seeds.zones.default] }
      service { Oaken::Seeds.services.default }
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
            build(:type_de_champ_repetition, :with_type_de_champs, procedure: procedure, mandatory: true, libelle: libelle, position: index)
          elsif type_champ == 'referentiel'
            referentiel = build(:api_referentiel, :exact_match)

            build(:type_de_champ_referentiel, procedure: procedure, mandatory: true, libelle: libelle, position: index, referentiel:)
          else
            build(:"type_de_champ_#{type_champ}", procedure: procedure, mandatory: true, libelle: libelle, position: index)
          end
        end
        build(:type_de_champ_drop_down_list, :long, procedure: procedure, mandatory: true, libelle: 'simple_choice_drop_down_list_long', position: TypeDeChamp.type_champs.size)
        build(:type_de_champ_multiple_drop_down_list, :long, procedure: procedure, mandatory: true, libelle: 'multiple_choice_drop_down_list_long', position: TypeDeChamp.type_champs.size + 1)
        build(:type_de_champ_piece_justificative, nature: 'titre_identite', mandatory: true, libelle: "titre_identité", procedure: procedure, position: TypeDeChamp.type_champs.size + 2)
      end
    end

    trait :with_all_champs do
      after(:build) do |procedure, _evaluator|
        TypeDeChamp.type_champs.map.with_index do |(libelle, type_champ), index|
          if libelle == 'drop_down_list'
            libelle = 'simple_drop_down_list'
          end
          if type_champ == 'repetition'
            build(:type_de_champ_repetition, :with_type_de_champs, procedure: procedure, libelle: libelle, position: index)
          elsif type_champ == 'referentiel'
            referentiel = build(:api_referentiel, :exact_match)

            build(:type_de_champ_referentiel, procedure: procedure, mandatory: true, libelle: libelle, position: index, referentiel:)
          else
            build(:"type_de_champ_#{type_champ}", procedure: procedure, libelle: libelle, position: index)
          end
        end
      end
    end

    # TODO: rewrite with private_type_de_champs
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

    trait :with_api_particulier_token do
      api_particulier_token { JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none') }
    end
  end
end

def build_type_de_champs(type_de_champs, revision:, scope: :public, parent: nil)
  type_de_champs.flat_map.with_index do |source_attributes, i|
    # `referentiel` et `children` sont lus sur la source, jamais sur la copie :
    # deep_dup duplique l'enregistrement ActiveRecord et la copie a un id nil.
    # Les children sont dupliqués par l'appel récursif, à leur tour.
    referentiel = source_attributes[:referentiel]
    children = source_attributes[:children]

    type_de_champ_attributes = source_attributes.except(:referentiel, :children).deep_dup
    type_de_champ_attributes[:referentiel_id] = referentiel.id if referentiel.present?

    type = TypeDeChamp.type_champs.fetch(type_de_champ_attributes.delete(:type) || :text).to_sym
    position = type_de_champ_attributes.delete(:position) || i
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
    # assigned rather than given to the factory, which would save the procedure half built
    type_de_champ.procedure = revision.procedure
    coordinate = build(:procedure_revision_type_de_champ,
      revision:,
      type_de_champ:,
      position:,
      parent:)

    if type_de_champ.repetition? && children.present?
      [coordinate] + build_type_de_champs(children, revision:, scope:, parent: coordinate)
    else
      coordinate
    end
  end
end
