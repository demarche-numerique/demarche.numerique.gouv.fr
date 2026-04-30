# frozen_string_literal: true

class ProcedureRevisionTypeDeChamp < ApplicationRecord
  belongs_to :revision, class_name: 'ProcedureRevision'
  belongs_to :type_de_champ

  belongs_to :parent, class_name: 'ProcedureRevisionTypeDeChamp', optional: true
  # this relationship is necessary for cascade with dependent: :destroy
  has_many :children_revision_types_de_champ, -> { ordered }, foreign_key: :parent_id, class_name: 'ProcedureRevisionTypeDeChamp', inverse_of: :parent, dependent: :destroy
  has_one :procedure, through: :revision
  scope :root, -> { where(parent: nil) }
  scope :ordered, -> { order(:position, :id) }
  scope :revision_ordered, -> { order(:revision_id) }
  scope :public_only, -> { joins(:type_de_champ).where(types_de_champ: { private: false }) }
  scope :private_only, -> { joins(:type_de_champ).where(types_de_champ: { private: true }) }

  delegate :libelle, :description, :type_champ, :header_section?, :repetition?, :mandatory?, :public?, :private?, :to_typed_id, to: :type_de_champ
  delegate :type_de_champ, to: :parent, prefix: true, allow_nil: true

  default_scope { eager_load(:type_de_champ) }

  def revision_types_de_champ = revision.revision_types_de_champ.filter { _1.persisted? ? _1.parent_id == id : _1.parent == self }.sort_by(&:position)
  def types_de_champ = revision_types_de_champ.map(&:type_de_champ)

  # significant perf gain when accessed hundreds of thousands of times in API or export context
  def stable_id
    @stable_id ||= type_de_champ.stable_id
  end

  def root?
    persisted? ? parent_id.nil? : parent.nil?
  end

  def child?
    parent_id.present?
  end

  def orphan?
    child? && !parent_type_de_champ.repetition?
  end

  def first?
    position == 0
  end

  def last?
    siblings.last == self
  end

  def empty?
    revision_types_de_champ.empty?
  end

  def siblings
    if child?
      parent.revision_types_de_champ
    elsif private?
      revision.revision_types_de_champ_private
    else
      revision.revision_types_de_champ_public
    end
  end

  def upper_coordinates
    upper = siblings.filter { |s| s.position < position }

    if child?
      upper += parent.upper_coordinates
    end

    if type_de_champ.private?
      upper += revision.revision_types_de_champ_public
    end

    upper
  end

  def siblings_starting_at(offset)
    siblings.filter { |s| (position + offset) <= s.position }
  end

  def previous_sibling
    index = siblings.index(self)
    if index > 0
      siblings[index - 1]
    end
  end

  def block
    if child?
      parent
    else
      revision
    end
  end

  def used_by_routing_rules?
    procedure.used_by_routing_rules?(type_de_champ)
  end

  def used_by_referentiel_urls?
    procedure.used_by_referentiel_urls?(type_de_champ)
  end

  def used_by_ineligibilite_rules?
    revision.ineligibilite_enabled? && stable_id.in?(revision.ineligibilite_rules&.sources || [])
  end

  def prefilled_by_type_de_champ
    revision.types_de_champ
      .filter(&:referentiel?)
      .find { stable_id.to_s.in?(it.referentiel_mapping_prefillable_stable_ids.map(&:to_s)) }
  end
end
