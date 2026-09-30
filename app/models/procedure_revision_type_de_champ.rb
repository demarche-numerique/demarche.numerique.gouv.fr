# frozen_string_literal: true

class ProcedureRevisionTypeDeChamp < ApplicationRecord
  belongs_to :revision, class_name: 'ProcedureRevision'
  belongs_to :type_de_champ

  belongs_to :parent, class_name: 'ProcedureRevisionTypeDeChamp', optional: true
  # this relationship is necessary for cascade with dependent: :destroy
  has_many :children_revision_type_de_champs, -> { ordered }, foreign_key: :parent_id, class_name: 'ProcedureRevisionTypeDeChamp', inverse_of: :parent, dependent: :destroy
  has_one :procedure, through: :revision
  scope :root, -> { where(parent: nil) }
  scope :ordered, -> { order(:position, :id) }
  scope :revision_ordered, -> { order(:revision_id) }
  scope :public_only, -> { joins(:type_de_champ).where(types_de_champ: { private: false }) }
  scope :private_only, -> { joins(:type_de_champ).where(types_de_champ: { private: true }) }

  delegate :libelle, :description, :type_champ, :header_section?, :repetition?, :mandatory?, :public?, :private?, :to_typed_id, to: :type_de_champ
  delegate :type_de_champ, to: :parent, prefix: true, allow_nil: true

  default_scope { eager_load(:type_de_champ) }

  def revision_type_de_champs = revision.revision_type_de_champs.filter { _1.persisted? ? _1.parent_id == id : _1.parent == self }.sort_by(&:position)
  def type_de_champs = revision_type_de_champs.map(&:type_de_champ)

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

  def first?
    position == 0
  end

  def last?
    siblings.last == self
  end

  def empty?
    revision_type_de_champs.empty?
  end

  def siblings
    if child?
      parent.revision_type_de_champs
    elsif private?
      revision.private_revision_type_de_champs
    else
      revision.public_revision_type_de_champs
    end
  end

  def upper_coordinates
    upper = preceding_siblings

    if child?
      upper += parent.upper_coordinates
    end

    if type_de_champ.private?
      upper += revision.public_revision_type_de_champs
    end

    upper
  end

  # Les coordonnées qu'une condition portée par celle-ci peut citer.
  def condition_source_coordinates
    sources = upper_coordinates

    if type_de_champ.public? && procedure.feature_enabled?(:annotation_condition_champs_public)
      sources += revision.private_revision_type_de_champs
    end

    sources
  end

  def preceding_siblings
    siblings.filter { it.position < position }
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
    revision.type_de_champs
      .filter(&:referentiel?)
      .find { stable_id.to_s.in?(it.referentiel_mapping_prefillable_stable_ids.map(&:to_s)) }
  end

  # La relation inverse de prefilled_by_type_de_champ : les coordonnées que le champ
  # référentiel porté par celle-ci peut préremplir. Dans son propre bloc, seules celles
  # qui le suivent — on ne préremplit pas une question déjà passée. Dans l'autre bloc,
  # toutes : l'ordre entre le formulaire et les annotations n'a pas de sens.
  def prefill_target_coordinates
    public_prefill_targets + private_prefill_targets
  end

  private

  def public_prefill_targets
    public_coordinates = revision.revision_type_de_champs.filter(&:public?)

    if private?
      procedure.feature_enabled?(:annotation_prefill_champs_public) ? public_coordinates : []
    else
      coordinates_after_self(public_coordinates)
    end
  end

  def private_prefill_targets
    private_coordinates = revision.revision_type_de_champs.filter(&:private?)

    private? ? coordinates_after_self(private_coordinates) : private_coordinates
  end

  # Dans une répétition, les frères qui suivent. À la racine, les coordonnées suivantes,
  # une répétition emportant ses enfants.
  def coordinates_after_self(coordinates)
    return siblings.filter { it.position > position } if child?

    coordinates.filter do |coordinate|
      coordinate.child? ? coordinate.parent.position >= position : coordinate.position > position
    end
  end
end
