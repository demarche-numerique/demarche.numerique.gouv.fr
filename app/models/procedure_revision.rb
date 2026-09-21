# frozen_string_literal: true

class ProcedureRevision < ApplicationRecord
  include Logic
  include RevisionDescribableToLLMConcern
  include RevisionComparisonConcern
  self.implicit_order_column = :created_at
  belongs_to :administrateur, optional: true
  belongs_to :procedure, -> { with_discarded }, inverse_of: :revisions, optional: false
  belongs_to :dossier_submitted_message, inverse_of: :revisions, optional: true, dependent: :destroy
  has_many :llm_rule_suggestions, dependent: :destroy, inverse_of: :procedure_revision
  has_many :dossiers, inverse_of: :revision, foreign_key: :revision_id
  has_many :revision_type_de_champs, -> { order(:position, :id) }, class_name: 'ProcedureRevisionTypeDeChamp', foreign_key: :revision_id, dependent: :destroy, inverse_of: :revision

  TypeDeChampLayout = Data.define(
    :type_de_champs_by_stable_id,
    :public_type_de_champs, :public_flat_type_de_champs, :public_root_type_de_champs,
    :private_type_de_champs, :private_flat_type_de_champs, :private_root_type_de_champs
  ) do
    def self.build(public_type_de_champs:, private_type_de_champs:)
      public_flat_type_de_champs, private_flat_type_de_champs = [public_type_de_champs, private_type_de_champs]
        .map { |type_de_champs| type_de_champs.flat_map { [it, *it.flat_children] }.freeze }

      new(
        type_de_champs_by_stable_id: (public_flat_type_de_champs + private_flat_type_de_champs).index_by(&:stable_id).freeze,
        public_type_de_champs:,
        public_flat_type_de_champs:,
        public_root_type_de_champs: public_flat_type_de_champs.reject(&:in_repetition?).freeze,
        private_type_de_champs:,
        private_flat_type_de_champs:,
        private_root_type_de_champs: private_flat_type_de_champs.reject(&:in_repetition?).freeze
      )
    end
  end
  private_constant :TypeDeChampLayout

  # Lays out the types de champ of several revisions in one query, where each
  # revision would run its own, anew if it already had. An instance goes to one
  # revision only: the others get their own instance of the type de champ
  # several revisions hold, built from the same row.
  def self.preload_type_de_champs(revisions)
    type_de_champ_ids = revisions.uniq.filter(&:persisted?).index_with { it.type_de_champ_tree.type_de_champ_ids }
    type_de_champs_by_id = TypeDeChamp.where(id: type_de_champ_ids.values.flatten.uniq).index_by(&:id)
    handed_ids = Set.new

    type_de_champ_ids.each do |revision, ids|
      own_type_de_champs_by_id = type_de_champs_by_id.slice(*ids).transform_values do |type_de_champ|
        handed_ids.add?(type_de_champ.id) ? type_de_champ : TypeDeChamp.instantiate(type_de_champ.attributes_before_type_cast)
      end

      revision.lay_out_type_de_champs(own_type_de_champs_by_id)
    end
  end

  def public_revision_type_de_champs = revision_type_de_champs.filter { _1.root? && _1.public? }.sort_by(&:position)
  def private_revision_type_de_champs = revision_type_de_champs.filter { _1.root? && _1.private? }.sort_by(&:position)

  # The types de champ, laid out from the tree: each one knows its ancestors
  # and its children (see TypeDeChamp#lay_out). These two hold the top of the
  # tree, the content of header sections and repetitions being within them.
  def public_type_de_champs = type_de_champ_layout.public_type_de_champs
  def private_type_de_champs = type_de_champ_layout.private_type_de_champs
  def type_de_champ(stable_id) = type_de_champ_layout.type_de_champs_by_stable_id[stable_id.to_i]

  # Lays out the types de champ again, from the tree as it is now. The ones
  # given are not loaded again, and become the revision's own: an instance
  # handed here must not be given to any other revision, nor be one a
  # coordinate holds, as it sits elsewhere in another revision.
  #
  # A node whose type de champ is gone is left out, with what it held: the
  # requests of the editor race, one removing what the tree of another names.
  def lay_out_type_de_champs(own_type_de_champs_by_id = {})
    raise ArgumentError, "a revision lays out its types de champ once saved: they have no stable id before" if new_record?

    tree = type_de_champ_tree
    missing_ids = tree.type_de_champ_ids - own_type_de_champs_by_id.keys
    type_de_champs_by_id = missing_ids.any? ? own_type_de_champs_by_id.merge(TypeDeChamp.where(id: missing_ids).index_by(&:id)) : own_type_de_champs_by_id

    @type_de_champ_layout = TypeDeChampLayout.build(
      public_type_de_champs: TypeDeChamp.laid_out(tree.public_children) { type_de_champs_by_id[it.type_de_champ_id] },
      private_type_de_champs: TypeDeChamp.laid_out(tree.private_children) { type_de_champs_by_id[it.type_de_champ_id] }
    )

    self
  end

  # All types de champ in document order, the content of header sections and
  # repetitions inlined after them.
  def type_de_champs = public_flat_type_de_champs + private_flat_type_de_champs
  def public_flat_type_de_champs = type_de_champ_layout.public_flat_type_de_champs
  def private_flat_type_de_champs = type_de_champ_layout.private_flat_type_de_champs
  # root as in not within a repetition: header sections and their content are all there
  def public_root_type_de_champs = type_de_champ_layout.public_root_type_de_champs
  def private_root_type_de_champs = type_de_champ_layout.private_root_type_de_champs

  has_one :draft_procedure, -> { with_discarded }, class_name: 'Procedure', foreign_key: :draft_revision_id, dependent: :nullify, inverse_of: :draft_revision
  has_one :published_procedure, -> { with_discarded }, class_name: 'Procedure', foreign_key: :published_revision_id, dependent: :nullify, inverse_of: :published_revision

  scope :ordered, -> { order(:created_at) }

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

  attribute :type_de_champ_tree, :type_de_champ_tree

  # Stored with every edit of a draft, and once and for all on publication. A
  # revision not backfilled yet builds it from its coordinates.
  def type_de_champ_tree
    super || TypeDeChampTree.from_coordinates(revision_type_de_champs)
  end

  # The tree as the coordinates have it by now: they remain what the editor
  # writes, the tree following them, until it edits the tree itself.
  def store_type_de_champ_tree
    with_lock { rebuild_type_de_champ_tree }

    self
  end

  def add_type_de_champ(params)
    parent_stable_id = params.delete(:parent_stable_id)
    parent_coordinate, _ = coordinate_and_tdc(parent_stable_id)
    parent_id = parent_coordinate&.id

    after_stable_id = params.delete(:after_stable_id)
    after_coordinate, _ = coordinate_and_tdc(after_stable_id)

    type_de_champ = TypeDeChamp.new(params)

    if params[:private].to_s == "true"
      type_de_champ.mandatory = false
    end

    if type_de_champ.save
      siblings = siblings_for(type_de_champ:, parent_coordinate:)
      position = next_position_for(after_coordinate:)

      edit_type_de_champs do
        # moving all the impacted tdc down
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..).unscope(:eager_load).update_all("position = position + 1")

        # insertion of the new tdc
        revision_type_de_champs.create!(type_de_champ:, parent_id:, position:)
      end
    end

    type_de_champ
  rescue => e
    TypeDeChamp.new.tap { _1.errors.add(:base, e.message) }
  end

  def find_and_ensure_exclusive_use(stable_id)
    coordinate, tdc = coordinate_and_tdc(stable_id)

    # replayed request targeting a tdc no longer in this revision (deleted in
    # another tab or by a previous request)
    raise ActiveRecord::RecordNotFound if tdc.nil?

    if tdc.only_present_on_draft?
      tdc
    else
      replace_type_de_champ_by_clone(coordinate)
    end
  end

  # What a type de champ is lays it out as much as where it is: a header
  # section holds what follows it, down to its level, and a repetition what is
  # within it.
  def update_type_de_champ(type_de_champ, params)
    type_de_champ.update(params).tap do |updated|
      store_type_de_champ_tree if updated && (type_de_champ.saved_change_to_type_champ? || type_de_champ.saved_change_to_options?)
    end
  end

  def move_type_de_champ(stable_id, position)
    coordinate, _ = coordinate_and_tdc(stable_id)
    siblings = coordinate.siblings

    edit_type_de_champs do
      if position > coordinate.position
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).unscope(:eager_load).update_all("position = position - 1")
      else
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..coordinate.position).unscope(:eager_load).update_all("position = position + 1")
      end
      coordinate.update_column(:position, position)
    end

    coordinate.reload
    coordinate
  end

  def move_type_de_champ_after(stable_id, position)
    coordinate, _ = coordinate_and_tdc(stable_id)
    siblings = coordinate.siblings

    edit_type_de_champs do
      if position > coordinate.position
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).unscope(:eager_load).update_all("position = position - 1")
        coordinate.update_column(:position, position)
      else
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: (position + 1)...coordinate.position).unscope(:eager_load).update_all("position = position + 1")
        coordinate.update_column(:position, position + 1)
      end
    end

    coordinate.reload
    coordinate
  end

  def remove_type_de_champ(stable_id)
    coordinate, tdc = coordinate_and_tdc(stable_id)

    # in case of replay
    return nil if coordinate.nil?

    # as the coordinates have it: the tree leaves out the children of anything
    # but a repetition, which are removed here before a publication
    children = coordinate.type_de_champs

    edit_type_de_champs do
      coordinate.destroy

      children.each(&:destroy_if_orphan)
      tdc.destroy_if_orphan

      ProcedureRevisionTypeDeChamp.where(id: coordinate.siblings, position: coordinate.position..).unscope(:eager_load).update_all("position = position - 1")
    end

    coordinate
  end

  def move_up_type_de_champ(stable_id)
    coordinate, _ = coordinate_and_tdc(stable_id)

    if coordinate.position > 0
      move_type_de_champ(stable_id, coordinate.position - 1)
    else
      coordinate
    end
  end

  def move_down_type_de_champ(stable_id)
    coordinate, _ = coordinate_and_tdc(stable_id)

    move_type_de_champ(stable_id, coordinate.position + 1)
  end

  # The types de champ are laid out again, from the tree as it is by then,
  # the next time they are read.
  def reset_type_de_champ_layout
    @type_de_champ_layout = nil
  end

  def reload(*)
    reset_type_de_champ_layout
    super
  end

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

  def type_de_champs_for(scope: nil)
    case scope
    when :public
      type_de_champs.filter(&:public?)
    when :private
      type_de_champs.filter(&:private?)
    else
      type_de_champs
    end
  end

  def children_of(tdc)
    type_de_champ(tdc.stable_id).flat_children
  end

  def parent_of(tdc)
    type_de_champ(tdc.stable_id)&.enclosing_repetition
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

  def coordinate_for(tdc)
    revision_type_de_champs.find { _1.stable_id == tdc.stable_id }
  end

  def carte?
    public_root_type_de_champs.any?(&:carte?)
  end

  def has_france_connect_type_de_champ?
    public_root_type_de_champs.any?(&:france_connect?)
  end

  def coordinate_and_tdc(stable_id)
    return [nil, nil] if stable_id.blank?

    coordinate = revision_type_de_champs
      .joins(:type_de_champ)
      .find_by(type_de_champ: { stable_id: stable_id })

    [coordinate, coordinate&.type_de_champ]
  end

  def simple_routable_type_de_champs
    public_root_type_de_champs.filter(&:simple_routable?)
  end

  def conditionable_type_de_champs
    type_de_champs_for(scope: :public).filter(&:conditionable?)
  end

  def champ_value_in_condition?
    conditions = type_de_champs.filter_map(&:condition) + [ineligibilite_rules].compact

    conditions
      .flat_map(&:terms)
      .any? { _1.is_a?(Logic::ChampValue) }
  end

  def apply_llm_rule_suggestion_items(changes)
    # Handle adds first, outside transaction to ensure stable_ids are generated and available
    created = changes.fetch(:add, []).each_with_object({}) do |item, accu|
      after_stable_id, libelle, header_section_level, generated_stable_id = item.payload.with_indifferent_access.values_at(:after_stable_id, :libelle, :header_section_level, :generated_stable_id)

      new_tdc = add_type_de_champ(after_stable_id:, type_champ: 'header_section', libelle:, header_section_level:)
      accu[generated_stable_id] = new_tdc if new_tdc.persisted? && generated_stable_id
    end

    # transaction do
    changes.fetch(:update, []).each do |item|
      payload = item.payload.with_indifferent_access

      if payload.key?(:after_stable_id) # StructureImprover: déplacement relatif
        stable_id, after_stable_id, header_section_level, libelle = payload.values_at(:stable_id, :after_stable_id, :header_section_level, :libelle)
        params = { header_section_level:, libelle: }.compact

        if after_stable_id.nil? # positionned at first
          coordinate = move_type_de_champ(stable_id, 0)
          if payload.key?(:header_section_level) && coordinate.type_de_champ.header_section? && params.present?
            update_type_de_champ(coordinate.type_de_champ, params)
          end
        else # positionned after another tdc
          if after_stable_id&.negative?
            after_tdc = created[after_stable_id]
            if after_tdc
              after_stable_id = created[after_stable_id].stable_id
            else
              item.failed!
              next
            end
          end

          after_coordinate, _ = coordinate_and_tdc(after_stable_id)
          if after_coordinate
            coordinate = move_type_de_champ_after(stable_id, after_coordinate.position)
            if payload.key?(:header_section_level) && coordinate.type_de_champ.header_section? && params.present?
              update_type_de_champ(coordinate.type_de_champ, params)
            end
          end
        end
      elsif payload.key?(:type_champ) # TypesImprover: type change
        stable_id, type_champ, options = payload.values_at(:stable_id, :type_champ, :options)

        tdc = find_and_ensure_exclusive_use(stable_id)
        tdc = tdc.becomes_type(type_champ) if type_champ != tdc.type_champ
        update_params = { type_champ: }
        update_params[:options] = tdc.options.merge(options) if options.present?
        update_type_de_champ(tdc, update_params)
      else # LabelImprover: mise à jour contenu
        stable_id, libelle, description = payload.values_at(:stable_id, :libelle, :description)

        tdc = find_and_ensure_exclusive_use(stable_id)
        tdc.update({ libelle:, description: }.compact)
      end
    end

    changes.fetch(:destroy, []).each do |llm_rule_suggestion_items|
      # TODO: verify conditional rules before
      remove_type_de_champ(llm_rule_suggestion_items.stable_id)
    end
  end

  private

  # Every edit of the draft goes through here, one at a time: the requests of
  # the editor race, and the tree of the one writing last has to be built from
  # the coordinates of them all.
  def edit_type_de_champs
    with_lock do
      yield.tap { rebuild_type_de_champ_tree }
    end
  end

  # within the lock of the revision, which has just read it again
  def rebuild_type_de_champ_tree
    type_de_champ_tree = TypeDeChampTree.from_coordinates(revision_type_de_champs.reset)
    update_columns(type_de_champ_tree:) if type_de_champ_tree != self[:type_de_champ_tree]
    reset_type_de_champ_layout
  end

  def type_de_champ_layout
    lay_out_type_de_champs if @type_de_champ_layout.nil?

    @type_de_champ_layout
  end

  def compute_estimated_fill_duration
    public_root_type_de_champs.sum do |tdc|
      next tdc.estimated_read_duration unless tdc.fillable?

      duration = tdc.estimated_read_duration + tdc.estimated_fill_duration(self)
      duration /= 2 unless tdc.mandatory?

      duration
    end
  end

  def siblings_for(type_de_champ:, parent_coordinate: nil)
    if parent_coordinate
      parent_coordinate.revision_type_de_champs
    elsif type_de_champ.private?
      private_revision_type_de_champs
    else
      public_revision_type_de_champs
    end
  end

  def next_position_for(after_coordinate: nil)
    # either we are at the beginning of the list or after another item
    if after_coordinate.nil? # first element of the list, starts at 0
      0
    else # after another item
      after_coordinate.position + 1
    end
  end

  def ineligibilite_rules_are_valid?
    return unless ineligibilite_rules

    rules_errors = ineligibilite_rules.errors(type_de_champs_for(scope: :public).to_a)

    if rules_errors.any? || ineligibilite_rules.type == :empty
      errors.add(:ineligibilite_rules, :invalid)
    end
  end

  def replace_type_de_champ_by_clone(coordinate)
    edit_type_de_champs do
      cloned_type_de_champ = coordinate.type_de_champ.deep_clone do |original, kopy|
        ClonePiecesJustificativesService.clone_attachments(original, kopy)
      end
      coordinate.update!(type_de_champ: cloned_type_de_champ)
      cloned_type_de_champ
    end
  end
end
