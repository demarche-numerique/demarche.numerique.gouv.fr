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

  # The ancestors a node may have: three levels of header sections, a
  # repetition, and three levels of header sections within it.
  MAX_DEPTH = 7

  class EditError < StandardError; end
  class TooDeepError < EditError; end

  class << self
    def from_json(json)
      json = json.symbolize_keys

      new(
        public_children: json.fetch(:public_children).map { TypeDeChampNode.from_json(it) },
        private_children: json.fetch(:private_children).map { TypeDeChampNode.from_json(it) }
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

    # The order spreadsheet exports had before the aggregate, out of the same
    # trees: per container (nil for the root, or a repetition's stable id), the
    # stable ids sorted public first, then by their position in the newest
    # revision holding their latest version, then the newest revision first.
    # A position is the rank in the container read as a flat list, where
    # header sections hold nothing.
    #
    # The positions that order relied on were not renumbered when a type de
    # champ was removed, and the trees only keep the rank: a few procedures
    # differ from the order they had.
    def legacy_export_order(trees)
      repetition_ids = repetition_type_de_champ_ids(trees)
      latest = {}

      trees.each_with_index do |tree, rank|
        [tree.public_nodes_with_ancestors, tree.private_nodes_with_ancestors].each_with_index do |nodes_with_ancestors, private|
          positions = Hash.new(0)

          nodes_with_ancestors.each do |node, ancestors|
            container = enclosing_repetition(ancestors, repetition_ids)&.stable_id
            keep_latest(latest, container, node, [private, positions[container], -rank])
            positions[container] += 1
          end
        end
      end

      latest
        .group_by { |(container, _), _| container }
        .transform_values { |entries| entries.sort_by { |(_, stable_id), (_, key)| [key, stable_id] }.map { |(_, stable_id), _| stable_id } }
    end

    # The stable ids the trees lay outside any repetition, the repetitions
    # themselves among them: header sections and what they hold are all there.
    def root_stable_ids(trees)
      repetition_ids = repetition_type_de_champ_ids(trees)

      trees
        .flat_map(&:nodes_with_ancestors)
        .filter_map { |node, ancestors| node.stable_id if enclosing_repetition(ancestors, repetition_ids).nil? }
        .uniq
    end

    private

    # the trees come oldest first: a later revision holding the same version wins
    def keep_latest(latest, container, node, key)
      kept = latest[[container, node.stable_id]]
      latest[[container, node.stable_id]] = [node.type_de_champ_id, key] if kept.nil? || node.type_de_champ_id >= kept.first
    end

    # the repetition a node sits in, if any: header sections do not count
    def enclosing_repetition(ancestors, repetition_ids)
      ancestors.find { repetition_ids.include?(it.type_de_champ_id) }
    end

    # only a repetition or a header section has children to tell apart
    def repetition_type_de_champ_ids(trees)
      ids = trees.flat_map(&:nodes).reject { it.children.empty? }.map(&:type_de_champ_id).uniq
      return Set.new if ids.empty?

      TypeDeChamp.where(id: ids, type_champ: TypeDeChamp.type_champs.fetch(:repetition)).ids.to_set
    end

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
  end

  def initialize(public_children: [], private_children: [])
    super(public_children: public_children.freeze, private_children: private_children.freeze)
  end

  # every node of the tree in document order, the public ones first
  def nodes = nodes_with_ancestors.map(&:first)

  # every type de champ the tree lays out, in document order: what to load in
  # one query before laying them out
  def type_de_champ_ids = nodes.map(&:type_de_champ_id)

  # every node in document order, each with its ancestors, the outermost first
  def public_nodes_with_ancestors = with_ancestors(public_children)
  def private_nodes_with_ancestors = with_ancestors(private_children)
  def nodes_with_ancestors = public_nodes_with_ancestors + private_nodes_with_ancestors

  def as_json(*) = { public_children: public_children.map(&:as_json), private_children: private_children.map(&:as_json) }

  # The same layout of other types de champ (the copies a clone makes), given
  # by the id of the one each of them stands in for.
  def with_type_de_champ_ids(ids)
    self.class.new(
      public_children: public_children.map { it.with_type_de_champ_ids(ids) },
      private_children: private_children.map { it.with_type_de_champ_ids(ids) }
    )
  end

  # The edits, each giving another tree. A node is named by its stable id, and
  # a place by the parent (:public and :private being the roots) and the
  # sibling to come after, first of the parent when none is given.
  #
  # The tree does not know what its nodes are: whether a parent may hold
  # anything, or a node leave its repetition, is for the one editing to tell.
  # It only stays a tree, holding a stable id once and nothing deeper than
  # MAX_DEPTH, and raises EditError when it would not.

  def insert(node, parent:, after: nil)
    held = stable_ids & stable_ids_of(node)
    raise EditError, "stable ids #{held.join(', ')} are already in the tree" if held.any?

    lay(node, parent:, after:)
  end

  # the node goes with what it holds
  def move(stable_id, parent:, after: nil)
    node, = node_with_ancestors(stable_id)
    raise EditError, "node #{stable_id} cannot go in what it holds" if stable_ids_of(node).include?(parent)

    splice(stable_id, []).lay(node, parent:, after:)
  end

  # children: :remove them along, or :inline them in place of the node
  def remove(stable_id, children: :remove)
    node, = node_with_ancestors(stable_id)

    case children
    when :remove then splice(stable_id, [])
    when :inline then splice(stable_id, node.children)
    else raise ArgumentError, "unknown children option: #{children.inspect}"
    end
  end

  # Another type de champ under the same stable id.
  # children: :remove them, :keep them, or :inline them right after the node
  def replace(stable_id, type_de_champ_id:, children: :remove)
    node, = node_with_ancestors(stable_id)

    case children
    when :remove then splice(stable_id, [node.with(type_de_champ_id:, children: [])])
    when :keep then splice(stable_id, [node.with(type_de_champ_id:)])
    when :inline then splice(stable_id, [node.with(type_de_champ_id:, children: []), *node.children])
    else raise ArgumentError, "unknown children option: #{children.inspect}"
    end
  end

  protected

  def lay(node, parent:, after:)
    case parent
    when :public
      check_depth(node, 0)
      with(public_children: laid_after(public_children, node, after))
    when :private
      check_depth(node, 0)
      with(private_children: laid_after(private_children, node, after))
    else
      container, ancestors = node_with_ancestors(parent)
      check_depth(node, ancestors.size + 1)
      splice(parent, [container.with(children: laid_after(container.children, node, after))])
    end
  end

  private

  def with_ancestors(nodes, ancestors = [])
    nodes.flat_map { [[it, ancestors], *with_ancestors(it.children, [*ancestors, it])] }
  end

  def stable_ids = nodes.map(&:stable_id)

  # the one of the node, and of what it holds
  def stable_ids_of(node) = with_ancestors([node]).map { |held, _| held.stable_id }

  def node_with_ancestors(stable_id)
    nodes_with_ancestors.find { |node, _| node.stable_id == stable_id } || raise(EditError, "node #{stable_id} is not in the tree")
  end

  # the nodes in place of the one named
  def splice(stable_id, nodes)
    with(public_children: spliced(public_children, stable_id, nodes), private_children: spliced(private_children, stable_id, nodes))
  end

  def spliced(siblings, stable_id, nodes)
    siblings.flat_map { it.stable_id == stable_id ? nodes : [it.with(children: spliced(it.children, stable_id, nodes))] }
  end

  def laid_after(siblings, node, after)
    index = after.nil? ? 0 : siblings.index { it.stable_id == after }&.succ
    raise EditError, "node #{after} is not a child of the parent" if index.nil?

    [*siblings].insert(index, node)
  end

  def check_depth(node, depth)
    raise TooDeepError, "nothing goes deeper than #{MAX_DEPTH} ancestors" if depth + height(node) > MAX_DEPTH
  end

  def height(node) = node.children.empty? ? 0 : 1 + node.children.map { height(it) }.max
end
