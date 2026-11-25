# frozen_string_literal: true

# The edits of a draft: its types de champ added, changed, moved and removed.
#
# FIXME: they write the coordinates, the tree following them, until the editor
# edits the tree itself (#14009).
module RevisionEditConcern
  extend ActiveSupport::Concern

  # A write to a column no foreign key refers to: FOR UPDATE would have every
  # dossier created on the revision wait, its foreign key check reading the row
  # FOR KEY SHARE.
  TYPE_DE_CHAMP_TREE_LOCK = 'FOR NO KEY UPDATE'

  def public_revision_type_de_champs = revision_type_de_champs.filter { _1.root? && _1.public? }.sort_by(&:position)
  def private_revision_type_de_champs = revision_type_de_champs.filter { _1.root? && _1.private? }.sort_by(&:position)

  # The tree as the coordinates have it by now: they remain what the editor
  # writes, the tree following them, until it edits the tree itself. For an
  # edit made elsewhere: a clone, a recovery import.
  #
  # FIXME: dropped, along with allow_published, once the editor writes the tree
  # and the coordinates are gone (#14009).
  def store_type_de_champ_tree = edit_type_de_champs(allow_published: true) { self }

  # The other way round, for a revision made out of a tree (a new draft): the
  # coordinates the editor is to write from.
  def create_coordinates_from_type_de_champ_tree
    type_de_champs_by_id = TypeDeChamp.where(id: type_de_champ_tree.type_de_champ_ids).index_by(&:id)

    type_de_champ_tree.to_coordinates(type_de_champs_by_id).each { it.update!(revision: self) }
    revision_type_de_champs.reset

    self
  end

  def add_type_de_champ(params)
    parent_stable_id = params.delete(:parent_stable_id)
    after_stable_id = params.delete(:after_stable_id)

    type_de_champ = TypeDeChamp.new(params)
    type_de_champ.procedure = procedure

    if params[:private].to_s == "true"
      type_de_champ.mandatory = false
    end

    # saved under the lock: a publication purges the types de champ no tree holds
    added = edit_type_de_champs do
      next false if !type_de_champ.save

      parent_coordinate = coordinate_by_stable_id(parent_stable_id)
      after_coordinate = coordinate_by_stable_id(after_stable_id)
      siblings = siblings_for(type_de_champ:, parent_coordinate:)
      position = next_position_for(after_coordinate:)

      # moving all the impacted tdc down
      ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..).unscope(:eager_load).update_all("position = position + 1")

      # insertion of the new tdc
      revision_type_de_champs.create!(type_de_champ:, parent_id: parent_coordinate&.id, position:)
    end

    if added
      # as the draft lays it out by now: the lock of the edit reloaded it
      type_de_champ(type_de_champ.stable_id)
    else
      type_de_champ
    end
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
        replace_type_de_champ_by_clone(coordinate_by_stable_id(stable_id))
        type_de_champ(stable_id)
      end
    end
  end

  # The type (header section, repetition) and the header section level shape
  # the tree as much as the coordinates do.
  # The lock lays the revision out anew: read the type de champ again
  # (type_de_champ(stable_id)) rather than keep the one given.
  def update_type_de_champ(type_de_champ, params)
    edit_type_de_champs { type_de_champ.update(params) }
  end

  # A move returns the type de champ where it is laid out by now.
  def move_type_de_champ(stable_id, position)
    move(stable_id) { move_coordinate(it, position) }
  end

  # After the sibling given, read under the lock as the one moved is: nil as
  # well when that one is gone.
  def move_type_de_champ_after(stable_id, after_stable_id)
    move(stable_id) do |coordinate|
      position = coordinate_by_stable_id(after_stable_id)&.position
      next if position.nil?

      siblings = coordinate.siblings

      if position > coordinate.position
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).unscope(:eager_load).update_all("position = position - 1")
        coordinate.update_column(:position, position)
      else
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: (position + 1)...coordinate.position).unscope(:eager_load).update_all("position = position + 1")
        coordinate.update_column(:position, position + 1)
      end

      coordinate.reload
    end
  end

  # The type de champ is left in place: it lives until the next publication
  # (or reset) of the procedure, which purges the types de champ no revision
  # lays out any more (ProcedurePublishConcern).
  def remove_type_de_champ(stable_id)
    edit_coordinate(stable_id) { remove_coordinate(it) }
  end

  # The coordinates the tree leaves out (TypeDeChampTree.from_coordinates): the
  # children of a former repetition, a legacy type de champ without a type, a
  # duplicate of a stable id. Cloned into every next revision otherwise.
  def coordinates_out_of_tree
    laid_out = TypeDeChampTree.from_coordinates(revision_type_de_champs).nodes.to_set(&:type_de_champ_id)

    revision_type_de_champs.reject { laid_out.include?(it.type_de_champ_id) }
  end

  # Under the lock of the revision, at publication: the positions of the
  # siblings shift. The tree is left as it is: it never held them.
  def remove_coordinates_out_of_tree
    # reloaded: a removal shifts the positions of the siblings left in place
    coordinates_out_of_tree.each { remove_coordinate(it.reload) }
    revision_type_de_champs.reset
  end

  def move_up_type_de_champ(stable_id)
    move(stable_id) do |coordinate|
      coordinate.position > 0 ? move_coordinate(coordinate, coordinate.position - 1) : coordinate
    end
  end

  def move_down_type_de_champ(stable_id)
    move(stable_id) { move_coordinate(it, it.position + 1) }
  end

  def coordinate_for(tdc)
    revision_type_de_champs.find { _1.stable_id == tdc.stable_id }
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
  # the editor race, and the tree of the one writing last has to be built from
  # the coordinates of them all. What an edit relies on (the coordinate it
  # moves, its siblings, the position it takes) is read inside as well: the
  # lock reloads the revision, so it sees the edits made in the meantime rather
  # than the ones a request was sent against. The coordinates are left to be
  # read again, as an edit always left them: the type de champ it hands over is
  # often updated next, past the ones they hold. The types de champ are laid out
  # again, as the lock reloads the tree.
  #
  # FIXME: allow_published is only for store_type_de_champ_tree, which follows
  # coordinates written outside the editor (recovery import, maintenance tasks),
  # on a published revision too. Dropped with it once the coordinates are gone
  # (#14009): a published revision is then refused without exception.
  def edit_type_de_champs(allow_published: false)
    raise ArgumentError, "save the revision before editing its types de champ: the lock reloads it" if new_record? || has_changes_to_save?

    with_lock(TYPE_DE_CHAMP_TREE_LOCK) do
      refuse_published_revision if !allow_published

      yield.tap do
        type_de_champ_tree = TypeDeChampTree.from_coordinates(revision_type_de_champs.reset)
        update_columns(type_de_champ_tree:) if type_de_champ_tree != self[:type_de_champ_tree]
        revision_type_de_champs.reset
      end
    end
  end

  private

  # A published revision is never edited. Read under the lock: an edit that
  # waited for it through the publication of its draft stops here.
  def refuse_published_revision
    raise ActiveRecord::RecordNotFound, "the revision is published: its types de champ are no longer edited" if published_at?
  end

  # Read from the database: a coordinate the tree leaves out included.
  def coordinate_by_stable_id(stable_id)
    return if stable_id.blank?

    revision_type_de_champs
      .joins(:type_de_champ)
      .find_by(type_de_champ: { stable_id: })
  end

  # Under the lock, on the coordinate as committed by the previous edits. nil
  # when the type de champ is no longer in the revision: a replayed request
  # (double click, removed in another tab).
  def edit_coordinate(stable_id)
    edit_type_de_champs do
      coordinate = coordinate_by_stable_id(stable_id)
      next if coordinate.nil?

      yield coordinate
    end
  end

  # nil as edit_coordinate
  def move(stable_id, &)
    type_de_champ(stable_id) if edit_coordinate(stable_id, &)
  end

  def move_coordinate(coordinate, position)
    siblings = coordinate.siblings

    if position > coordinate.position
      ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).unscope(:eager_load).update_all("position = position - 1")
    else
      ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..coordinate.position).unscope(:eager_load).update_all("position = position + 1")
    end
    coordinate.update_column(:position, position)

    coordinate.reload
  end

  # cascades to the children coordinates of a repetition
  def remove_coordinate(coordinate)
    coordinate.destroy

    ProcedureRevisionTypeDeChamp.where(id: coordinate.siblings, position: coordinate.position..).unscope(:eager_load).update_all("position = position - 1")

    coordinate
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

  def replace_type_de_champ_by_clone(coordinate)
    edit_type_de_champs do
      cloned_type_de_champ = coordinate.type_de_champ.deep_clone do |original, kopy|
        ClonePiecesJustificativesService.clone_attachments(original, kopy)
        kopy.procedure = procedure
      end
      coordinate.update!(type_de_champ: cloned_type_de_champ)
      cloned_type_de_champ
    end
  end
end
