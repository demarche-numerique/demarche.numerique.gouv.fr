# frozen_string_literal: true

class TypeDeChamp < ApplicationRecord
  # Standard STI: the type column holds the class name and Rails resolves it
  # natively. The historical type_champ vocabulary is derived from the class;
  # its column is no longer read here and is kept aligned by a database
  # trigger for code that still speaks it.

  include EstimatedDurationConcern

  STRUCTURE = :structure
  ETAT_CIVIL = :etat_civil
  LOCALISATION = :localisation
  PAIEMENT_IDENTIFICATION = :paiement_identification
  STANDARD = :standard
  PIECES_JOINTES = :pieces_jointes
  CHOICE = :choice
  REFERENTIEL_EXTERNE = :referentiel_externe
  FRANCE_CONNECT = :france_connect

  CATEGORIES = [STRUCTURE, ETAT_CIVIL, LOCALISATION, PAIEMENT_IDENTIFICATION, STANDARD, PIECES_JOINTES, CHOICE, REFERENTIEL_EXTERNE, FRANCE_CONNECT]

  def self.category = STANDARD
  def self.feature_flag = nil
  def self.private_only? = false
  def self.public_only? = false
  def self.allowed_in_repetition? = true
  def self.simple_routable? = false
  def self.conditionable? = false

  # The single dictionary between the classes and the domain vocabulary,
  # formerly the STI discriminator. The vocabulary is only spoken at the
  # frontiers: API v1 serializers, GraphQL, the LLM contract and the i18n
  # keys. The order drives the editor and the seeds.
  CLASS_NAME_TO_TYPE_CHAMP = {
    'TypesDeChamp::EngagementJuridique' => 'engagement_juridique',
    'TypesDeChamp::HeaderSection' => 'header_section',
    'TypesDeChamp::Repetition' => 'repetition',
    'TypesDeChamp::DossierLink' => 'dossier_link',
    'TypesDeChamp::Explication' => 'explication',
    'TypesDeChamp::Civilite' => 'civilite',
    'TypesDeChamp::Email' => 'email',
    'TypesDeChamp::Phone' => 'phone',
    'TypesDeChamp::Address' => 'address',
    'TypesDeChamp::Commune' => 'communes',
    'TypesDeChamp::Departement' => 'departements',
    'TypesDeChamp::Region' => 'regions',
    'TypesDeChamp::Pays' => 'pays',
    'TypesDeChamp::Iban' => 'iban',
    'TypesDeChamp::Siret' => 'siret',
    'TypesDeChamp::Text' => 'text',
    'TypesDeChamp::Textarea' => 'textarea',
    'TypesDeChamp::Number' => 'number',
    'TypesDeChamp::DecimalNumber' => 'decimal_number',
    'TypesDeChamp::IntegerNumber' => 'integer_number',
    'TypesDeChamp::Formatted' => 'formatted',
    'TypesDeChamp::Date' => 'date',
    'TypesDeChamp::Datetime' => 'datetime',
    'TypesDeChamp::PieceJustificative' => 'piece_justificative',
    'TypesDeChamp::Checkbox' => 'checkbox',
    'TypesDeChamp::DropDownList' => 'drop_down_list',
    'TypesDeChamp::MultipleDropDownList' => 'multiple_drop_down_list',
    'TypesDeChamp::LinkedDropDownList' => 'linked_drop_down_list',
    'TypesDeChamp::YesNo' => 'yes_no',
    'TypesDeChamp::AnnuaireEducation' => 'annuaire_education',
    'TypesDeChamp::RNA' => 'rna',
    'TypesDeChamp::RNF' => 'rnf',
    'TypesDeChamp::Carte' => 'carte',
    'TypesDeChamp::Epci' => 'epci',
    'TypesDeChamp::COJO' => 'cojo',
    'TypesDeChamp::Referentiel' => 'referentiel',
    'TypesDeChamp::PreRempli' => 'pre_rempli',
    'TypesDeChamp::QuotientFamilial' => 'quotient_familial',
    'TypesDeChamp::EtudiantBoursier' => 'etudiant_boursier',
    'TypesDeChamp::AAH' => 'aah',
    'TypesDeChamp::AEEH' => 'aeeh',
    'TypesDeChamp::ARS' => 'ars',
  }.freeze

  TYPE_CHAMP_TO_CLASS_NAME = CLASS_NAME_TO_TYPE_CHAMP.invert.freeze
  TYPE_CHAMPS = CLASS_NAME_TO_TYPE_CHAMP.values.index_by(&:itself).with_indifferent_access.freeze
  CHAMP_TYPE_TO_TYPE_CHAMP = CLASS_NAME_TO_TYPE_CHAMP.to_h do |name, type_champ|
    ["#{name.sub('TypesDeChamp::', 'Champs::')}Champ", type_champ]
  end.freeze

  def self.type_champs = TYPE_CHAMPS

  # enum-compatible predicates (text?, piece_justificative?, …) until the call
  # sites move to is_a?
  TYPE_CHAMPS.each_key do |key|
    define_method(:"#{key}?") { type_champ == key }
  end

  has_many :revision_type_de_champs, -> { revision_ordered }, class_name: 'ProcedureRevisionTypeDeChamp', dependent: :destroy, inverse_of: :type_de_champ

  has_many :revisions, -> { ordered }, through: :revision_type_de_champs

  belongs_to :referentiel, optional: true, inverse_of: :type_de_champs

  attribute :options, IndifferentJsonbType.new

  serialize :condition, coder: LogicSerializer

  scope :public_only, -> { where(private: false) }
  scope :private_only, -> { where(private: true) }
  scope :repetition, -> { where(type: TypesDeChamp::Repetition.name) }
  scope :not_repetition, -> { where.not(type: TypesDeChamp::Repetition.name) }
  scope :not_condition, -> { where(condition: nil) }
  scope :fillable, -> { where.not(type: [TypesDeChamp::HeaderSection, TypesDeChamp::Explication].map(&:name)) }
  scope :with_header_section, -> { where.not(type: TypesDeChamp::Explication.name) }
  scope :mandatory, -> { where(mandatory: true) }

  scope :dubious, -> {
    where("unaccent(types_de_champ.libelle) ~* unaccent(?)", DubiousProcedure.forbidden_regexp)
      .where(type: [TypesDeChamp::Text, TypesDeChamp::Textarea].map(&:name))
  }

  has_one_attached :piece_justificative_template
  has_one_attached :notice_explicative

  validates :type, presence: true, allow_blank: false, allow_nil: false

  after_create :populate_stable_id

  before_validation :enforce_mandatory_constraints
  before_validation :set_default_libelle, if: -> { type_changed? }

  normalizes :libelle, with: -> (value) { value.strip }

  before_save :remove_attachment, if: -> { type_changed? }
  before_save :clean_referentiel

  def libelle_with_parent(revision)
    if child?(revision)
      parent_type_de_champ = revision.parent_of(self)
      "#{parent_type_de_champ.libelle} - #{libelle}"
    else
      libelle
    end
  end

  def libelle_optionnal? = false
  def libelle_configurable? = true
  def description_configurable? = true
  def has_label? = true
  def customizable? = false

  def params_for_champ
    {
      type_de_champ: self,
      private: private?,
      type: champ_class.name,
      stable_id:,
      stream: Dossier::MAIN_STREAM,
    }
  end

  def champ_class
    self.class.champ_class
  end

  def build_champ(params = {})
    champ_class.new(params_for_champ.merge(params))
  end

  # the model no longer reads the column: the vocabulary is derived from the class
  def type_champ = self.class.type_champ

  def only_present_on_draft?
    revisions.one? && revisions.first.draft?
  end

  def prefillable? = false

  def fillable? = true

  def must_be_mandatory? = false

  def cannot_be_mandatory? = false

  def public?
    !private?
  end

  def france_connect? = false

  def api_particulier? = false

  def any_drop_down_list? = false

  def child?(revision)
    revision.coordinate_for(self)&.child?
  end

  def options_for_select = nil

  def previous_section_level(upper_tdcs)
    previous_header_section = upper_tdcs.reverse.find(&:header_section?)

    return 0 if !previous_header_section
    previous_header_section.header_section_level_value.to_i
  end

  def current_section_level(revision)
    tdcs = private? ? revision.private_root_type_de_champs.to_a : revision.public_root_type_de_champs.to_a

    previous_section_level(tdcs.take(tdcs.find_index(self)))
  end

  def to_typed_id
    GraphQL::Schema::UniqueWithinType.encode('Champ', stable_id)
  end

  def read_attribute_for_serialization(name)
    if name == 'id'
      stable_id
    else
      super
    end
  end

  def destroy_if_orphan
    if revision_type_de_champs.empty?
      destroy
    end
  end

  # dom ids follow the stable_id so they survive the revision clones
  def to_key = ([stable_id] if stable_id)

  # We should refresh all champs after update except for champs using react or
  # custom refresh logic (RNA, SIRET, etc.)
  def refresh_after_update? = true

  def simple_routable? = self.class.simple_routable?

  def conditionable? = self.class.conditionable?

  def condition_value_type = :unmanaged
  def condition_options = []

  def public_id(row_id)
    self.class.public_id(stable_id, row_id)
  end

  def self.option_keys = []
  def self.column_type = :text

  def clean_options
    options.slice(*self.class.option_keys.map(&:to_s))
  end

  def allowed_content_types = AUTHORIZED_CONTENT_TYPES

  def champ_value(champ)
    if champ_blank?(champ)
      champ_default_value
    else
      typed_champ_value(champ)
    end
  end

  def champ_value_for_api(champ, version: 2)
    if champ_blank?(champ)
      champ_default_api_value(version)
    else
      typed_champ_value_for_api(champ, version:)
    end
  end

  def champ_value_for_export(champ, path = :value)
    if champ_blank?(champ)
      champ_default_export_value(path)
    else
      typed_champ_value_for_export(champ, path)
    end
  end

  def champ_value_for_tag(champ, path = :value)
    if champ_blank?(champ)
      ''
    else
      typed_champ_value_for_tag(champ, path)
    end
  end

  def champ_blank?(champ)
    # no champ
    return true if champ.nil?
    # type de champ on the revision changed
    if champ.is_type?(type_champ) || castable_on_change?(champ.last_write_type_champ, type_champ)
      typed_champ_blank?(champ)
    else
      true
    end
  end

  def mandatory_blank?(champ)
    # no champ
    return true if champ.nil?
    # type de champ on the revision changed
    if champ.is_type?(type_champ) || castable_on_change?(champ.last_write_type_champ, type_champ)
      mandatory? && typed_champ_blank_or_invalid?(champ)
    else
      true
    end
  end

  def typed_champ_value(champ)
    champ.value.present? ? champ_text_value(champ) : champ_default_value
  end

  def typed_champ_value_for_api(champ, version: 2)
    case version
    when 2
      typed_champ_value(champ)
    else
      champ.value.presence || champ_default_api_value(version)
    end
  end

  def typed_champ_value_for_export(champ, path = :value)
    path == :value ? champ_text_value(champ).presence : champ_default_export_value(path)
  end

  def typed_champ_value_for_tag(champ, path = :value)
    path == :value ? typed_champ_value(champ) : nil
  end

  def champ_default_value
    ''
  end

  def champ_default_export_value(path = :value)
    nil
  end

  def champ_default_api_value(version = 2)
    case version
    when 2
      ''
    else
      nil
    end
  end

  def typed_champ_blank?(champ) = champ.value.blank?
  def typed_champ_blank_or_invalid?(champ) = typed_champ_blank?(champ)

  def tags_for_template
    type_de_champ = self
    conditional = type_de_champ.condition.present?
    paths.map do |path|
      path.merge(
        libelle: TagsSubstitutionConcern::TagsParser.normalize(path[:libelle]),
        id: path[:path] == :value ? "tdc#{stable_id}" : "tdc#{stable_id}/#{path[:path]}",
        conditional:,
        mandatory: mandatory?,
        lambda: -> (dossier) { dossier.champ_value_for_tag(type_de_champ, path[:path]) }
      )
    end
  end

  def libelles_for_export
    paths.map { [_1[:libelle], _1[:path]] }
  end

  def canonical_column(procedure_id:, displayable: true, prefix: nil)
    return nil unless fillable?

    Columns::ChampColumn.new(
      procedure_id:,
      stable_id:,
      tdc_type: type_champ,
      label: libelle_with_prefix(prefix),
      type: self.class.column_type,
      displayable:,
      options_for_select:,
      mandatory: mandatory?
    )
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    [canonical_column(procedure_id:, displayable:, prefix:)].compact
  end

  def customization_column(procedure_id:)
    columns(procedure_id:).find(&:displayable)
  end

  def info_columns(procedure:)
    # Extract labels from columns, removing the libelle prefix automatically
    # Example: "Commune - code postal" => "code postal"
    regex_prefix = /^#{Regexp.escape(libelle)}[^\p{L}]+/

    columns(procedure_id: procedure.id).filter_map do |column|
      column.label.sub(regex_prefix, '')
    end
  end

  def html_id(row_id = nil)
    "champ-#{public_id(row_id)}"
  end

  class << self
    def public_id(stable_id, row_id)
      if row_id.blank?
        stable_id.to_s
      else
        "#{stable_id}-#{row_id}"
      end
    end

    # The champ hierarchy mirrors this one name for name:
    # TypesDeChamp::Text -> Champs::TextChamp
    def champ_class
      "Champs::#{name.demodulize}Champ".constantize
    end

    def class_for(type_champ) = TYPE_CHAMP_TO_CLASS_NAME.fetch(type_champ.to_s).constantize

    # The editor boundary: resolves a submitted class name against the
    # dictionary, never constantizing the input.
    def class_for_name(type_name) = type_champ_classes.index_by(&:name).fetch(type_name)

    def type_champ = CLASS_NAME_TO_TYPE_CHAMP[name]

    def type_champ_classes = type_champs.values.map { class_for(_1) }

    def conditionable_types = type_champ_classes.filter(&:conditionable?)

    def simple_routable_types = conditionable_types.filter(&:simple_routable?)

    def custom_routable_types = conditionable_types.reject(&:simple_routable?)

    # Forms, params, dom ids and i18n keys expect 'type_de_champ' for every subclass.
    def model_name
      self == TypeDeChamp ? super : TypeDeChamp.model_name
    end

    # Predicates over jsonb options read as booleans: the editor form writes
    # "1"/"0", the defaults and the LLM improver write true/false.
    def boolean_options(*keys)
      keys.each do |key|
        define_method(:"#{key}?") { ActiveModel::Type::Boolean.new.cast(public_send(key)) || false }
      end
    end
  end

  private

  def set_default_libelle
    old_default, new_default = [CLASS_NAME_TO_TYPE_CHAMP[type_was], type_champ].map do |type_champ|
      next if type_champ.blank?

      I18n.t(type_champ,
        scope: [:activerecord, :attributes, :type_de_champ, :default_libelle],
        default: I18n.t(type_champ, scope: [:activerecord, :attributes, :type_de_champ, :type_champs]), app_name: APPLICATION_NAME)
    end

    self.libelle = new_default if libelle.blank? || libelle == old_default
  end

  def enforce_mandatory_constraints
    return if mandatory_changed?

    self.mandatory = false if !fillable? || cannot_be_mandatory?
    self.mandatory = true if must_be_mandatory?
  end

  # A value written by a multiple drop-down list, read after a type change.
  def champ_text_value(champ)
    if champ.is_type?(TypeDeChamp.type_champs.fetch(:multiple_drop_down_list))
      TypesDeChamp::MultipleDropDownList.parse_selected_options(champ).join(', ')
    else
      champ.value
    end
  end

  def libelle_with_prefix(prefix)
    [prefix, libelle].compact.join(' – ')
  end

  def paths
    [
      {
        libelle:,
        path: :value,
        description:,
      },
    ]
  end

  def castable_on_change?(from_type, to_type)
    Columns::ChampColumn::CAST.key?([from_type.to_sym, to_type.to_sym])
  end

  def populate_stable_id
    if !stable_id
      update_column(:stable_id, id)
    end
  end

  def remove_attachment
    if !piece_justificative? && piece_justificative_template.attached?
      piece_justificative_template.purge_later
    elsif !explication? && notice_explicative.attached?
      notice_explicative.purge_later
    end
  end

  def clean_referentiel
    return if !persisted? || !type_changed? || !referentiel_id?
    self.referentiel_id = nil
  end
end
