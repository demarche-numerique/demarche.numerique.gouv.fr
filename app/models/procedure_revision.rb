# frozen_string_literal: true

class ProcedureRevision < ApplicationRecord
  include Logic
  include RevisionDescribableToLLMConcern
  include RevisionComparisonConcern
  include RevisionEditConcern
  self.implicit_order_column = :created_at
  belongs_to :administrateur, optional: true
  belongs_to :procedure, -> { with_discarded }, inverse_of: :revisions, optional: false
  belongs_to :dossier_submitted_message, inverse_of: :revisions, optional: true, dependent: :destroy
  has_many :llm_rule_suggestions, dependent: :destroy, inverse_of: :procedure_revision
  has_many :dossiers, inverse_of: :revision, foreign_key: :revision_id
  # FIXME: no longer written nor read. The rows left in the table refer to the
  # revision, and go with it until the table is dropped (#14009).
  has_many :revision_type_de_champs, class_name: 'ProcedureRevisionTypeDeChamp', foreign_key: :revision_id, dependent: :destroy, inverse_of: :revision

  # Lays out the types de champ of several revisions in one query, where each
  # revision would run its own, anew if it already had. An instance goes to one
  # revision only: the others get their own instance of the type de champ
  # several revisions hold, built from the same row. Two instances of one
  # revision are two revisions here, each laid out.
  def self.preload_type_de_champs(revisions)
    trees = revisions.uniq(&:object_id).filter(&:persisted?).map { [it, it.type_de_champ_tree] }
    type_de_champs_by_id = TypeDeChamp.where(id: trees.flat_map { it.last.type_de_champ_ids }.uniq).index_by(&:id)
    handed_ids = Set.new

    trees.each do |revision, tree|
      own_type_de_champs_by_id = type_de_champs_by_id.slice(*tree.type_de_champ_ids).transform_values do |type_de_champ|
        handed_ids.add?(type_de_champ.id) ? type_de_champ : TypeDeChamp.instantiate(type_de_champ.attributes_before_type_cast)
      end

      revision.lay_out_type_de_champs(own_type_de_champs_by_id)
    end
  end

  # The types de champ, laid out from the tree: each one knows its ancestors
  # and its children (see TypeDeChamp#lay_out). These two hold the top of the
  # tree, the content of header sections and repetitions being within them.
  def public_type_de_champs = type_de_champ_layout.public_type_de_champs
  def private_type_de_champs = type_de_champ_layout.private_type_de_champs
  def type_de_champ(stable_id) = type_de_champ_layout.type_de_champ(stable_id)

  # Lays out the types de champ again, from the tree as it is now. The ones
  # given are not loaded again, and become the revision's own: an instance
  # handed here must not be given to any other revision, where it sits
  # elsewhere.
  def lay_out_type_de_champs(own_type_de_champs_by_id = {})
    raise ArgumentError, "a revision lays out its types de champ once saved: they have no stable id before" if new_record?

    tree = type_de_champ_tree
    # the layout first: were it to fail, the tree would say it is there
    @type_de_champ_layout = TypeDeChampLayout.lay_out(tree, own_type_de_champs_by_id, revision: self)
    @laid_out_type_de_champ_tree = tree

    self
  end

  def type_de_champs_laid_out? = @laid_out_type_de_champ_tree.equal?(type_de_champ_tree)

  def type_de_champs = type_de_champ_layout.type_de_champs
  def public_flat_type_de_champs = type_de_champ_layout.public_flat_type_de_champs
  def private_flat_type_de_champs = type_de_champ_layout.private_flat_type_de_champs
  # root as in not within a repetition: header sections and their content are all there
  def public_root_type_de_champs = type_de_champ_layout.public_root_type_de_champs
  def private_root_type_de_champs = type_de_champ_layout.private_root_type_de_champs
  def root_type_de_champs = type_de_champ_layout.root_type_de_champs

  has_one :draft_procedure, -> { with_discarded }, class_name: 'Procedure', foreign_key: :draft_revision_id, dependent: :nullify, inverse_of: :draft_revision
  has_one :published_procedure, -> { with_discarded }, class_name: 'Procedure', foreign_key: :published_revision_id, dependent: :nullify, inverse_of: :published_revision

  scope :ordered, -> { order(:created_at) }
  # the database searches the trees: those of a procedure weigh up to a few megabytes
  scope :laying_out, -> (type_de_champ) { where("jsonb_path_exists(type_de_champ_tree, 'strict $.** ? (@.type_de_champ_id == $id)', CAST(:vars AS jsonb))", vars: { id: type_de_champ.id }.to_json) }

  validates :ineligibilite_message, presence: true, if: -> { ineligibilite_enabled? }

  delegate :path, to: :procedure, prefix: true

  validate :ineligibilite_rules_are_valid?,
    on: [:ineligibilite_rules_editor, :publication]
  validates :ineligibilite_message,
    presence: true,
    if: -> { ineligibilite_enabled? },
    on: [:ineligibilite_rules_editor, :publication]
  validates :ineligibilite_rules,
    presence: true,
    if: -> { ineligibilite_enabled? },
    on: [:ineligibilite_rules_editor, :publication]

  serialize :ineligibilite_rules, coder: LogicSerializer

  # Stored with every edit of a draft, and once and for all on publication.
  # Empty at creation, the column default: never null.
  attribute :type_de_champ_tree, :type_de_champ_tree

  def draft?
    procedure.draft_revision_id == id
  end

  def locked?
    !draft?
  end

  def dossier_for_preview(user)
    dossier = Dossier
      .create_with(autorisation_donnees: true)
      .find_or_initialize_by(revision: self, user: user, for_procedure_preview: true, state: Dossier.states.fetch(:brouillon))

    if dossier.new_record?
      dossier.build_default_values
      dossier.save!
    end

    dossier
  end

  # Every Logic tree this champ's value feeds, beyond the visibility of another
  # question: the eligibility rules and the routing rules read it too, and a
  # repetition child can condition on it — which dependent_conditions, limited
  # to the root type de champs, does not reach. None of the three is recomputed
  # once the dossier is submitted.
  def used_by_a_condition?(tdc)
    stable_id = tdc.stable_id

    # Une question du formulaire peut être conditionnée par une annotation : la dépendance va
    # dans les deux sens, il faut scanner les deux collections.
    return true if type_de_champs.any? { it.condition? && it.condition.sources.include?(stable_id) }
    return true if ineligibilite_enabled? && ineligibilite_rules&.sources&.include?(stable_id)

    procedure.used_by_routing_rules?(tdc)
  end

  def dependent_conditions(tdc)
    stable_id = tdc.stable_id

    tdcs = tdc.public? ? public_root_type_de_champs + private_root_type_de_champs : private_root_type_de_champs
    tdcs.filter do |other_tdc|
      next if !other_tdc.condition?

      other_tdc.condition.sources.include?(stable_id)
    end
  end

  # Estimated duration to fill the form, in seconds.
  #
  # If the revision is locked (i.e. published), the result is cached (because type de champs can no longer be mutated).
  def estimated_fill_duration
    Rails.cache.fetch("#{cache_key_with_version}/estimated_fill_duration", expires_in: 12.hours, force: !locked?) do
      compute_estimated_fill_duration
    end
  end

  def carte?
    public_root_type_de_champs.any?(&:carte?)
  end

  def has_france_connect_type_de_champ?
    public_root_type_de_champs.any?(&:france_connect?)
  end

  def simple_routable_type_de_champs
    public_root_type_de_champs.filter(&:simple_routable?)
  end

  def conditionable_type_de_champs
    public_flat_type_de_champs.filter(&:conditionable?)
  end

  def champ_value_in_condition?
    conditions = type_de_champs.filter_map(&:condition) + [ineligibilite_rules].compact

    conditions
      .flat_map(&:terms)
      .any? { _1.is_a?(Logic::ChampValue) }
  end

  private

  # The instances laid out are the revision's own, loaded for it: another
  # revision lays out the same types de champ elsewhere.
  #
  # They are laid out from the stored tree, and again once it is another
  # object: an edit writes it, a reload reads it again.
  def type_de_champ_layout
    lay_out_type_de_champs if !type_de_champs_laid_out?

    @type_de_champ_layout
  end

  def compute_estimated_fill_duration
    public_root_type_de_champs.sum do |tdc|
      next tdc.estimated_read_duration unless tdc.fillable?

      duration = tdc.estimated_read_duration + tdc.estimated_fill_duration
      duration /= 2 unless tdc.mandatory?

      duration
    end
  end

  def ineligibilite_rules_are_valid?
    return unless ineligibilite_rules

    # The solver only judges rules that are in use: leftover rules of a
    # disabled ineligibility must not block publication
    tdcs = public_flat_type_de_champs
    rules_errors = ineligibilite_enabled? ? Logic.errors(ineligibilite_rules, tdcs) : ineligibilite_rules.errors(tdcs)

    if rules_errors.any? || ineligibilite_rules.type == :empty
      errors.add(:ineligibilite_rules, :invalid)
    end
  end
end
