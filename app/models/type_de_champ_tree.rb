# frozen_string_literal: true

# The layout of a revision's types de champ: which ones it holds, in which
# order, and which repetition or header section contains them.
class TypeDeChampTree < Data.define(:public_children, :private_children)
  class << self
    def from_json(json)
      json = json.symbolize_keys

      new(
        public_children: json.fetch(:public_children).map { TypeDeChampNode.from_json(it) },
        private_children: json.fetch(:private_children).map { TypeDeChampNode.from_json(it) }
      )
    end

    # Coordinates hold the repetitions' content explicitly (parent), and the
    # header sections' content implicitly (every following sibling, up to the
    # next header section of the same level or above). The tree holds both
    # explicitly.
    #
    # Header section levels are normalized to the closest correct tree: a
    # section nests in the nearest preceding section of a lower level, however
    # many levels are skipped in between (h1, h3: the h3 is a child of the h1).
    # Document order is always preserved.
    #
    # What the app cannot use is left out: a legacy type de champ without a
    # type, the child of anything but a repetition, and all but one of the
    # coordinates holding the same stable id.
    def from_coordinates(coordinates)
      coordinates = deduplicated(usable(coordinates))
      # a coordinate not yet saved has no id to be referenced by
      children_by_parent = coordinates
        .reject(&:root?)
        .group_by { it.persisted? ? it.parent_id : it.parent }
      public_coordinates, private_coordinates = coordinates.filter(&:root?).partition(&:public?)

      new(
        public_children: nodes_for(public_coordinates, children_by_parent),
        private_children: nodes_for(private_coordinates, children_by_parent)
      )
    end

    private

    def usable(coordinates)
      coordinates = coordinates.reject { it.type_champ.blank? }
      coordinates_by_id = coordinates.filter(&:persisted?).index_by(&:id)

      coordinates.filter do |coordinate|
        next true if coordinate.root?

        parent = coordinate.persisted? ? coordinates_by_id[coordinate.parent_id] : coordinate.parent
        parent.present? && parent.repetition?
      end
    end

    # Bugs long fixed left a few revisions holding a stable id twice: the
    # children of a repetition also laid at the root, the child of a repetition
    # edited into a copy which never replaced it. The coordinate within a
    # repetition wins over the one at the root, then the latest type de champ.
    #
    # When the coordinate left out is a repetition, its children go with it:
    # they hang on its id, not on the one of the coordinate which is kept.
    def deduplicated(coordinates)
      coordinates.group_by(&:stable_id).flat_map do |stable_id, duplicates|
        # types de champ not yet saved have no stable id
        next duplicates if stable_id.nil? || duplicates.one?

        [duplicates.max_by { [it.root? ? 0 : 1, it.type_de_champ_id.to_i, it.id.to_i] }]
      end
    end

    def nodes_for(siblings, children_by_parent)
      section_children(ordered(siblings), 0, children_by_parent)
    end

    # consumes the siblings belonging to the open section, given by its declared
    # level (0 being no section at all), and leaves in the queue the header
    # section closing it. Levels compare as declared, not as nested: an h2
    # following a rooted h3 closes it.
    def section_children(queue, open_level, children_by_parent)
      nodes = []

      while (coordinate = queue.first)
        type_de_champ = coordinate.type_de_champ

        if type_de_champ.header_section?
          level = type_de_champ.header_section_level_value.clamp(1..)
          break if level <= open_level

          queue.shift
          nodes << node_for(coordinate, section_children(queue, level, children_by_parent))
        elsif type_de_champ.repetition?
          queue.shift
          children = children_by_parent.fetch(coordinate.persisted? ? coordinate.id : coordinate, [])
          nodes << node_for(coordinate, nodes_for(children, children_by_parent))
        else
          queue.shift
          nodes << node_for(coordinate, [])
        end
      end

      nodes
    end

    def node_for(coordinate, children)
      TypeDeChampNode.new(stable_id: coordinate.stable_id, type_de_champ_id: coordinate.type_de_champ_id, children:)
    end

    def ordered(coordinates) = coordinates.sort_by { [it.position, it.id.to_i] }
  end

  def initialize(public_children: [], private_children: [])
    super(public_children: public_children.freeze, private_children: private_children.freeze)
  end

  # every node of the tree in document order, the public ones first
  def nodes = nodes_of(public_children) + nodes_of(private_children)

  def as_json(*) = { public_children: public_children.map(&:as_json), private_children: private_children.map(&:as_json) }

  private

  def nodes_of(nodes) = nodes.flat_map { [it, *nodes_of(it.children)] }
end
