# frozen_string_literal: true

# The layout of a revision's types de champ: which ones it holds, in which
# order, and which repetition or header section contains them.
class TypeDeChampTree < Data.define(:public_children, :private_children)
  # a node while trees are merged: its children are an array left open, where
  # the ones of a TypeDeChampNode are frozen
  MergedNode = Data.define(:stable_id, :type_de_champ_id, :children, :parent) do
    def to_node = TypeDeChampNode.new(stable_id:, type_de_champ_id:, children: children.map(&:to_node))
  end
  private_constant :MergedNode

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

    # One tree out of the trees of a procedure's published revisions, from the
    # oldest to the newest, holding every type de champ any of them held. Each
    # tree is merged in the aggregate of the ones before, as if publication
    # after publication:
    #
    # - the newest tree gives the layout, and the version of each type de champ;
    # - a type de champ removed since comes at the end of its last-known
    #   container, a removed container with the content removed along with it,
    #   the latest removed first;
    # - a type de champ moved since is only where the newest tree lays it.
    def aggregate(trees)
      kinds = container_kinds(trees)

      trees.reduce(new) do |aggregate, tree|
        new(
          public_children: merged(tree.public_children, aggregate.public_children, kinds),
          private_children: merged(tree.private_children, aggregate.private_children, kinds)
        )
      end
    end

    private

    def merged(newest, aggregated, kinds)
      root = MergedNode.new(stable_id: nil, type_de_champ_id: nil, children: [], parent: nil)
      merged_by_stable_id = {}

      graft(newest, root, merged_by_stable_id, kinds)
      graft(aggregated, root, merged_by_stable_id, kinds)

      root.children.map(&:to_node)
    end

    # lays the nodes not merged yet at the end of the container, which is nil
    # when their content has nowhere to go
    def graft(nodes, container, merged_by_stable_id, kinds)
      nodes.each do |node|
        merged = merged_by_stable_id[node.stable_id]

        if merged
          graft(node.children, container_of_content(node, merged, kinds), merged_by_stable_id, kinds)
        elsif container
          merged = MergedNode.new(stable_id: node.stable_id, type_de_champ_id: node.type_de_champ_id, children: [], parent: container)
          container.children << merged
          merged_by_stable_id[node.stable_id] = merged
          graft(node.children, merged, merged_by_stable_id, kinds)
        end
      end
    end

    # A type de champ keeps its stable id when its type changes. What a
    # repetition held means nothing out of it, and is left out; what a header
    # section held goes to the container the former header section sits in.
    def container_of_content(node, merged, kinds)
      kind, merged_kind = kinds.values_at(node.type_de_champ_id, merged.type_de_champ_id)

      if node.children.empty? || kind == merged_kind
        merged
      elsif kind == TypeDeChamp.type_champs.fetch(:header_section)
        merged.parent
      end
    end

    # the type of each version of the types de champ which had children and
    # changed since: nothing to look up, most of the time
    def container_kinds(trees)
      nodes = trees.flat_map(&:nodes)
      container_stable_ids = nodes.reject { it.children.empty? }.to_set(&:stable_id)
      type_de_champ_ids = nodes
        .filter { it.stable_id.in?(container_stable_ids) }
        .group_by(&:stable_id)
        .flat_map { |_, versions| versions.map(&:type_de_champ_id).uniq.then { it.many? ? it : [] } }
      return {} if type_de_champ_ids.empty?

      TypeDeChamp.where(id: type_de_champ_ids).pluck(:id, :type_champ).to_h
    end

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
