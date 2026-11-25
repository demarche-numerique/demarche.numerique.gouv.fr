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

      [evaluator.public_type_de_champs, evaluator.private_type_de_champs].each do |type_de_champs|
        if type_de_champs.present? && !type_de_champs.first.is_a?(Hash)
          raise "public_type_de_champs and private_type_de_champs must be arrays of hashes"
        end
      end

      if procedure.brouillon?
        procedure.draft_revision = initial_revision
      else
        procedure.published_revision = initial_revision
        procedure.published_revision.published_at = Time.zone.now
        procedure.draft_revision = build(:procedure_revision, from_original: initial_revision)
      end
    end

    after(:create) do |procedure, evaluator|
      # The types de champ are created once the procedure is saved: the tree
      # names them by their ids. The draft of a published procedure lays out
      # the same ones as the published revision.
      type_de_champ_tree = TypeDeChampTree.new(
        public_children: create_type_de_champ_nodes(evaluator.public_type_de_champs, procedure:, scope: :public),
        private_children: create_type_de_champ_nodes(evaluator.private_type_de_champs, procedure:, scope: :private)
      )
      [procedure.draft_revision, procedure.published_revision].compact.each { it.update_columns(type_de_champ_tree:) }

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
      public_type_de_champs do
        [
          *all_type_de_champs_for_factory(mandatory: true),
          { type: :drop_down_list, mandatory: true, libelle: 'simple_choice_drop_down_list_long', options: ["alpha", "bravo", "charly", "delta", "echo", "fox-trot", "golf"] },
          { type: :multiple_drop_down_list, mandatory: true, libelle: 'multiple_choice_drop_down_list_long', options: ["alpha", "bravo", "charly", "delta", "echo", "fox-trot", "golf"] },
          { type: :piece_justificative, nature: 'titre_identite', mandatory: true, libelle: "titre_identité" },
        ]
      end
    end

    trait :with_all_champs do
      public_type_de_champs { all_type_de_champs_for_factory }
    end

    trait :with_all_annotations do
      private_type_de_champs { all_type_de_champs_for_factory(repetition_children: []) }
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

# one of every type, named after its type
def all_type_de_champs_for_factory(repetition_children: [{ libelle: 'sub type de champ' }, { type: :integer_number, libelle: 'sub type de champ2' }], **attributes)
  TypeDeChamp.type_champs.map do |libelle, type_champ|
    libelle = 'simple_drop_down_list' if libelle == 'drop_down_list'

    case type_champ
    when 'repetition'
      { type: :repetition, libelle:, children: repetition_children, **attributes }
    when 'referentiel'
      { type: :referentiel, libelle:, referentiel: build(:api_referentiel, :exact_match), **attributes, mandatory: true }
    else
      { type: type_champ.to_sym, libelle:, **attributes }
    end
  end
end

# The nodes of the types de champ described, each created for the procedure,
# in document order. A repetition holds its children, and so does a header
# section given some. One given a level instead (1 when given none) holds what
# follows it, up to the next header section of its level or above: the form
# as a flat list of titles reads.
def create_type_de_champ_nodes(type_de_champs, procedure:, scope: :public)
  type_de_champ_nodes_for_factory(lay_type_de_champs_for_factory(type_de_champs, procedure:, scope:))
end

# each type de champ with what it holds, laid the same way
def lay_type_de_champs_for_factory(type_de_champs, procedure:, scope:)
  root = []
  # the header sections left open, innermost last: [level, what it holds]
  open_sections = []

  type_de_champs.each do |attributes|
    type_de_champ = create_type_de_champ_for_factory(attributes.except(:children, :level), procedure:, scope:)

    if type_de_champ.header_section? && !attributes.key?(:children)
      level = attributes.fetch(:level, 1).to_i
      open_sections.pop while open_sections.any? && open_sections.last.first >= level
      held = []
      (open_sections.last&.last || root) << [type_de_champ, held]
      open_sections << [level, held]
    else
      held = lay_type_de_champs_for_factory(attributes[:children].to_a, procedure:, scope:)
      (open_sections.last&.last || root) << [type_de_champ, held]
    end
  end

  root
end

def type_de_champ_nodes_for_factory(laid)
  laid.map do |type_de_champ, held|
    TypeDeChampNode.new(stable_id: type_de_champ.stable_id, type_de_champ_id: type_de_champ.id, children: type_de_champ_nodes_for_factory(held))
  end
end

def create_type_de_champ_for_factory(source_attributes, procedure:, scope: :public)
  # `referentiel` est lu sur la source, jamais sur la copie : deep_dup duplique
  # l'enregistrement ActiveRecord et la copie a un id nil.
  referentiel = source_attributes[:referentiel]

  type_de_champ_attributes = source_attributes.except(:referentiel).deep_dup
  type_de_champ_attributes[:referentiel] = referentiel if referentiel.present?

  type = TypeDeChamp.type_champs.fetch(type_de_champ_attributes.delete(:type) || :text).to_sym
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

  traits = scope == :private ? [:private] : []
  create(:"type_de_champ_#{type}", *traits, laid_out: false, procedure:, **type_de_champ_attributes)
end
