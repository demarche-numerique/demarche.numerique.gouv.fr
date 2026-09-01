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

  def public_revision_type_de_champs = revision_type_de_champs.filter { _1.root? && _1.public? }.sort_by(&:position)
  def private_revision_type_de_champs = revision_type_de_champs.filter { _1.root? && _1.private? }.sort_by(&:position)
  def type_de_champs = revision_type_de_champs.map(&:type_de_champ)
  def public_root_type_de_champs = public_revision_type_de_champs.map(&:type_de_champ)
  def private_root_type_de_champs = private_revision_type_de_champs.map(&:type_de_champ)

  # All types de champ in document order, repetition children inlined after their repetition.
  def public_flat_type_de_champs = public_revision_type_de_champs.flat_map { [it, *it.revision_type_de_champs] }.map(&:type_de_champ)
  def private_flat_type_de_champs = private_revision_type_de_champs.flat_map { [it, *it.revision_type_de_champs] }.map(&:type_de_champ)

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

      transaction do
        # moving all the impacted tdc down
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..).unscope(:eager_load).update_all("position = position + 1")

        # insertion of the new tdc
        revision_type_de_champs.create!(type_de_champ:, parent_id:, position:)
      end

      revision_type_de_champs.reset
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

  def move_type_de_champ(stable_id, position)
    coordinate, _ = coordinate_and_tdc(stable_id)
    siblings = coordinate.siblings

    transaction do
      if position > coordinate.position
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).unscope(:eager_load).update_all("position = position - 1")
      else
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..coordinate.position).unscope(:eager_load).update_all("position = position + 1")
      end
      coordinate.update_column(:position, position)
    end

    revision_type_de_champs.reset
    coordinate.reload
    coordinate
  end

  def move_type_de_champ_after(stable_id, position)
    coordinate, _ = coordinate_and_tdc(stable_id)
    siblings = coordinate.siblings

    transaction do
      if position > coordinate.position
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).unscope(:eager_load).update_all("position = position - 1")
        coordinate.update_column(:position, position)
      else
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: (position + 1)...coordinate.position).unscope(:eager_load).update_all("position = position + 1")
        coordinate.update_column(:position, position + 1)
      end
    end

    revision_type_de_champs.reset
    coordinate.reload
    coordinate
  end

  def remove_type_de_champ(stable_id)
    coordinate, tdc = coordinate_and_tdc(stable_id)

    # in case of replay
    return nil if coordinate.nil?

    children = children_of(tdc).to_a

    transaction do
      coordinate.destroy

      children.each(&:destroy_if_orphan)
      tdc.destroy_if_orphan

      ProcedureRevisionTypeDeChamp.where(id: coordinate.siblings, position: coordinate.position..).unscope(:eager_load).update_all("position = position - 1")
    end

    revision_type_de_champs.reset
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
    coordinate_for(tdc).type_de_champs
  end

  def parent_of(tdc)
    coordinate = coordinate_for(tdc)
    if coordinate&.child?
      revision_type_de_champs.find { _1.id == coordinate.parent_id }&.type_de_champ
    end
  end

  def dependent_conditions(tdc)
    stable_id = tdc.stable_id

    (tdc.public? ? public_root_type_de_champs : private_root_type_de_champs).filter do |other_tdc|
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
            coordinate.type_de_champ.update(params)
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
              coordinate.type_de_champ.update(params)
            end
          end
        end
      elsif payload.key?(:type_champ) # TypesImprover: type change
        stable_id, type_champ, nature, options = payload.values_at(:stable_id, :type_champ, :nature, :options)

        tdc = find_and_ensure_exclusive_use(stable_id)
        tdc = tdc.becomes_type(type_champ) if type_champ != tdc.type_champ
        update_params = { type_champ: }
        update_params[:nature] = nature if nature.present?
        update_params[:options] = tdc.options.merge(options) if options.present?
        tdc.update(update_params)
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
    transaction do
      cloned_type_de_champ = coordinate.type_de_champ.deep_clone do |original, kopy|
        ClonePiecesJustificativesService.clone_attachments(original, kopy)
      end
      coordinate.update!(type_de_champ: cloned_type_de_champ)
      cloned_type_de_champ
    end
  end
end
