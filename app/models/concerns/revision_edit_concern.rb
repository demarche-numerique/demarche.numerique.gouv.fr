# frozen_string_literal: true

# The edits of a draft: its types de champ added, changed, moved and removed.
#
# The editor lists every block flat (the form, the annotations, what a
# repetition holds), a header section being a title among its siblings. An
# edit is made on the tree flattened that way, which is then folded again by
# the declared levels of the header sections (TypeDeChampTree::Flat).
#
# FIXME: the edits are to be the ones of a tree of sections (#14009).
module RevisionEditConcern
  extend ActiveSupport::Concern

  # A write to a column no foreign key refers to: FOR UPDATE would have every
  # dossier created on the revision wait, its foreign key check reading the row
  # FOR KEY SHARE.
  TYPE_DE_CHAMP_TREE_LOCK = 'FOR NO KEY UPDATE'

  def add_type_de_champ(params)
    parent_stable_id = params.delete(:parent_stable_id)
    after_stable_id = params.delete(:after_stable_id)

    type_de_champ = TypeDeChamp.new(params)
    type_de_champ.procedure = procedure

    if params[:private].to_s == "true"
      type_de_champ.mandatory = false
    end

    # saved under the lock: a publication purges the types de champ no tree holds
    added = edit_flat_type_de_champ_tree do |flat|
      next [false, flat] if !type_de_champ.save

      node = TypeDeChampNode.new(stable_id: type_de_champ.stable_id, type_de_champ_id: type_de_champ.id)
      parent = parent_stable_id.presence&.to_i || (type_de_champ.private? ? :private : :public)

      [true, flat.insert(node, parent:, after: after_stable_id.presence&.to_i)]
    end

    if added
      # as the draft lays it out by now: the lock of the edit reloaded it
      type_de_champ(type_de_champ.stable_id)
    else
      type_de_champ
    end
  rescue TypeDeChampTree::EditError
    # the place asked for is gone: the parent, or the sibling to come after
    TypeDeChamp.new.tap { it.errors.add(:base, I18n.t('activerecord.errors.type_de_champ.not_added.place_gone')) }
  rescue => e
    TypeDeChamp.new.tap { _1.errors.add(:base, e.message) }
  end

  # Decided under the lock: two requests editing a shared type de champ at once
  # would otherwise each clone it, the last one orphaning the clone of the
  # first along with its edit.
  def find_and_ensure_exclusive_use(stable_id)
    with_lock(TYPE_DE_CHAMP_TREE_LOCK) do
      refuse_published_revision

      # read once locked: the lock lays the revision out anew
      tdc = type_de_champ(stable_id)

      # replayed request targeting a tdc no longer in this revision (deleted in
      # another tab or by a previous request)
      raise ActiveRecord::RecordNotFound if tdc.nil?

      if tdc.only_present_on_draft?
        tdc
      else
        replace_type_de_champ_by_clone(tdc)
        type_de_champ(stable_id)
      end
    end
  end

  # The type (header section, repetition) and the header section level shape
  # the tree as much as the order does.
  # The lock lays the revision out anew: read the type de champ again
  # (type_de_champ(stable_id)) rather than keep the one given.
  def update_type_de_champ(type_de_champ, params)
    edit_type_de_champs { type_de_champ.update(params) }
  end

  # A move returns the type de champ where it is laid out by now. The
  # position is the one among its siblings: the ones its block lists.
  def move_type_de_champ(stable_id, position)
    move(stable_id) { position }
  end

  # After the sibling given, read under the lock as the one moved is: nil as
  # well when that one is gone, or sits in another block.
  def move_type_de_champ_after(stable_id, after_stable_id)
    move(stable_id) do |siblings|
      siblings.without(stable_id.to_i).index(after_stable_id.to_i)&.succ
    end
  end

  # The type de champ is left in place: it lives until the next publication
  # (or reset) of the procedure, which purges the types de champ no revision
  # lays out any more (ProcedurePublishConcern).
  #
  # Returns whether it was laid out: no longer when the request is replayed
  # (double click, removed in another tab).
  def remove_type_de_champ(stable_id)
    stable_id = stable_id.to_i

    edit_flat_type_de_champ_tree do |flat|
      next [false, flat] if flat.nodes.none? { it.stable_id == stable_id }

      # what a repetition holds goes with it
      [true, flat.remove(stable_id)]
    end
  end

  def move_up_type_de_champ(stable_id)
    move(stable_id) { |siblings| siblings.index(stable_id.to_i) - 1 }
  end

  def move_down_type_de_champ(stable_id)
    move(stable_id) { |siblings| siblings.index(stable_id.to_i) + 1 }
  end

  def apply_llm_rule_suggestion_items(changes)
    # Handle adds first, outside transaction to ensure stable_ids are generated and available
    created = changes.fetch(:add, []).each_with_object({}) do |item, accu|
      after_stable_id, libelle, header_section_level, generated_stable_id = item.payload.with_indifferent_access.values_at(:after_stable_id, :libelle, :header_section_level, :generated_stable_id)

      new_tdc = add_type_de_champ(after_stable_id:, type_champ: 'header_section', libelle:, header_section_level:)
      item.failed! if !new_tdc.persisted?
      accu[generated_stable_id] = new_tdc if new_tdc.persisted? && generated_stable_id
    end

    # transaction do
    changes.fetch(:update, []).each do |item|
      payload = item.payload.with_indifferent_access

      if payload.key?(:after_stable_id) # StructureImprover: déplacement relatif
        stable_id, after_stable_id, header_section_level, libelle = payload.values_at(:stable_id, :after_stable_id, :header_section_level, :libelle)
        params = { header_section_level:, libelle: }.compact

        if after_stable_id.nil? # positionned at first
          moved = move_type_de_champ(stable_id, 0)
          if payload.key?(:header_section_level) && moved.header_section? && params.present?
            update_type_de_champ(find_and_ensure_exclusive_use(stable_id), params)
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

          moved = move_type_de_champ_after(stable_id, after_stable_id)
          if payload.key?(:header_section_level) && moved&.header_section? && params.present?
            update_type_de_champ(find_and_ensure_exclusive_use(stable_id), params)
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

  # Every edit of the draft goes through here, one at a time: the requests of
  # the editor race, and each has to edit the tree the one before left. The
  # lock reloads the revision: what an edit relies on (the tree, where a type
  # de champ sits in it) is read inside, so it sees the edits made in the
  # meantime rather than the ones a request was sent against. The types de
  # champ are laid out again, as the lock reloads the tree.
  #
  # The tree is folded again whatever the edit: the type (header section,
  # repetition) and the header section level shape it as much as the order.
  def edit_type_de_champs
    edit_flat_type_de_champ_tree { |flat| [yield, flat] }
  end

  private

  # A published revision is never edited. Read under the lock: an edit that
  # waited for it through the publication of its draft stops here.
  def refuse_published_revision
    raise ActiveRecord::RecordNotFound, "the revision is published: its types de champ are no longer edited" if published_at?
  end

  # The block is given the tree flattened and answers what the edit returns,
  # along with the flat tree as the edit leaves it.
  #
  # Flattened before the edit: what a repetition held is only left out by the
  # fold once it is no longer one, where what a header section held stays. An
  # edit made within another is refused for the same reason: the tree it
  # stores would be left out by the fold of the one around it.
  def edit_flat_type_de_champ_tree
    raise ArgumentError, "save the revision before editing its types de champ: the lock reloads it" if new_record? || has_changes_to_save?
    raise ArgumentError, "the types de champ are being edited: an edit made within another would be lost" if @editing_type_de_champs

    begin
      @editing_type_de_champs = true

      with_lock(TYPE_DE_CHAMP_TREE_LOCK) do
        refuse_published_revision

        answer, flat = yield type_de_champ_tree.flatten(repetitions: type_de_champ_kinds(type_de_champ_tree).fetch(:repetitions))
        tree = flat.fold(**type_de_champ_kinds(flat))
        update_columns(type_de_champ_tree: tree) if tree != type_de_champ_tree

        answer
      end
    ensure
      @editing_type_de_champs = false
    end
  end

  # what tells the trees apart: the options are not loaded, some hold thousands of choices
  def type_de_champ_kinds(tree)
    kinds = TypeDeChamp
      .where(id: tree.type_de_champ_ids, type_champ: [TypeDeChamp.type_champs.fetch(:header_section), TypeDeChamp.type_champs.fetch(:repetition)])
      .pluck(:id, :type_champ, Arel.sql("options->>'header_section_level'"))
    repetitions, header_sections = kinds.partition { |_, type_champ, _| type_champ == TypeDeChamp.type_champs.fetch(:repetition) }

    {
      repetitions: repetitions.to_set(&:first),
      levels: header_sections.to_h { |id, _, level| [id, level.presence&.to_i || 1] },
    }
  end

  # what holds the type de champ in the flat tree (a root or its repetition),
  # and the stable ids listed there, its own included
  def flat_siblings(flat, stable_id)
    { public: flat.public_nodes_with_ancestors, private: flat.private_nodes_with_ancestors }.each do |root, nodes_with_ancestors|
      node, ancestors = nodes_with_ancestors.find { |node, _| node.stable_id == stable_id }
      next if node.nil?

      siblings = ancestors.last&.children || (root == :public ? flat.public_children : flat.private_children)
      return [ancestors.last&.stable_id || root, siblings.map(&:stable_id)]
    end

    nil
  end

  # The block is given the siblings of the type de champ, itself included, and
  # answers the position it takes among them: nil to leave it where it is.
  # Returns nil as well when the type de champ is no longer in the revision: a
  # replayed request (double click, removed in another tab).
  def move(stable_id)
    stable_id = stable_id.to_i

    moved = edit_flat_type_de_champ_tree do |flat|
      parent, siblings = flat_siblings(flat, stable_id)
      position = yield siblings if siblings
      next [false, flat] if position.nil?

      others = siblings.without(stable_id)
      # a position past the ends is the end
      after = others[position.clamp(0, others.size) - 1] if position > 0

      [true, flat.move(stable_id, parent:, after:)]
    end

    type_de_champ(stable_id) if moved
  end

  def replace_type_de_champ_by_clone(type_de_champ)
    edit_flat_type_de_champ_tree do |flat|
      cloned_type_de_champ = type_de_champ.deep_clone do |original, kopy|
        ClonePiecesJustificativesService.clone_attachments(original, kopy)
        kopy.procedure = procedure
      end
      cloned_type_de_champ.save!

      [cloned_type_de_champ, flat.replace(type_de_champ.stable_id, type_de_champ_id: cloned_type_de_champ.id, children: :keep)]
    end
  end
end
