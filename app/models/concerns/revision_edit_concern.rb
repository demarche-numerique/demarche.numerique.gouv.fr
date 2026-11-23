# frozen_string_literal: true

# The edits of a draft: its types de champ added, changed, moved and removed.
#
# Each edit takes the row lock of the revision, reads the tree as the edits
# before it left it, checks what the editor allows, and writes the tree once.
# The tree itself only knows that it stays a tree (TypeDeChampTree): the rules
# are here.
#
# - A block is the form, the annotations, or what a repetition holds. A type
#   de champ never leaves its block: the rows already filled would no longer
#   read (#14105).
# - Only a header section and a repetition hold anything.
# - A block refuses some types: a repetition within a repetition, an
#   annotation type in the form.
# - Three levels of header sections per block.
# - A type de champ the published revision lays out takes its published type,
#   or a type it converts to (Columns::ChampColumn::CAST). Neither a header
#   section nor a repetition is in the table: once published, they keep their
#   type. Anything not published yet is free, but a repetition holding types
#   de champ: they would leave the draft with its type.
# - Removing a repetition removes what it holds, removing a header section
#   leaves what it holds in its place. A type de champ the routing, a
#   referentiel or the eligibility rules read is not removed, nor changes type.
#
# A type de champ left out of the tree stays in the database until the next
# publication or reset of the draft, which purge the ones no revision lays out
# (ProcedurePublishConcern).
module RevisionEditConcern
  extend ActiveSupport::Concern

  # An edit the rules refuse. The message is for the administrateur.
  class RefusedError < StandardError; end

  MAX_SECTION_LEVEL = 3

  # A write to a column no foreign key refers to: FOR UPDATE would have every
  # dossier created on the revision wait, its foreign key check reading the row
  # FOR KEY SHARE.
  TYPE_DE_CHAMP_TREE_LOCK = 'FOR NO KEY UPDATE'

  # the types a published type converts to
  CASTABLE_TYPE_CHAMPS = Columns::ChampColumn::CAST.keys
    .group_by { |(from)| from.to_s }
    .transform_values { |pairs| pairs.map { |(_, to)| to.to_s } }
    .freeze

  # Every edit goes through here, one at a time: the requests of the editor
  # race. The lock reloads the revision: the block reads the tree as the edits
  # committed before it left it, and changes it in memory
  # (type_de_champ_tree=). It is written once, when the block returns. An edit
  # made of others holds the lock once.
  #
  # A published revision is never edited. Read under the lock: an edit that
  # waited for it through the publication of its draft stops here.
  def edit_type_de_champs
    return yield if @editing_type_de_champs

    raise ArgumentError, "save the revision before editing its types de champ: the lock reloads it" if new_record? || has_changes_to_save?

    with_lock(TYPE_DE_CHAMP_TREE_LOCK) do
      raise ActiveRecord::RecordNotFound, "the revision is published: its types de champ are no longer edited" if published_at?

      @editing_type_de_champs = true

      yield.tap { write_type_de_champ_tree if type_de_champ_tree_changed? }
    ensure
      @editing_type_de_champs = false
      # the tree a refused edit left: the transaction rolls back the rest
      restore_attributes([:type_de_champ_tree])
    end
  end

  # First of the parent given (a header section, a repetition, or none for the
  # form or the annotations), or right after a sibling. Returns the type de
  # champ as the draft lays it out, or holding the errors which refused it.
  def add_type_de_champ(params)
    params = params.to_h.symbolize_keys
    parent_stable_id = params.delete(:parent_stable_id).presence
    after_stable_id = params.delete(:after_stable_id).presence

    # refused before it is built: an unknown type has no class
    refuse(:unknown_type) if params[:type_champ].present? && !TypeDeChamp.type_champs.value?(params[:type_champ].to_s)

    type_de_champ = TypeDeChamp.new(params)
    type_de_champ.procedure = procedure

    # saved under the lock: a publication purges the types de champ no tree holds
    edit_type_de_champs do
      after = laid_out_type_de_champ(after_stable_id) if after_stable_id
      parent = after ? after.parent : (laid_out_type_de_champ(parent_stable_id) if parent_stable_id)

      type_de_champ.private = (after || parent).private? if after || parent
      type_de_champ.mandatory = false if type_de_champ.private?

      check_holds(parent)
      check_type_champ_allowed(type_de_champ.type_champ, repetition: block_of_content(parent), private: type_de_champ.private?)
      check_section_levels(parent, 1) if type_de_champ.header_section?

      next type_de_champ if !type_de_champ.save

      node = TypeDeChampNode.new(stable_id: type_de_champ.stable_id, type_de_champ_id: type_de_champ.id)
      self.type_de_champ_tree = type_de_champ_tree.insert(node, parent: parent&.stable_id || root_of(type_de_champ), after: after&.stable_id)
      lay_out_type_de_champs(type_de_champ.id => type_de_champ).type_de_champ(type_de_champ.stable_id)
    end
  rescue RefusedError, TypeDeChampTree::EditError => e
    TypeDeChamp.new.tap { it.errors.add(:base, e.message) }
  end

  # The type de champ to change, the draft's own: one the published revision
  # lays out as well is first replaced by a copy. Decided under the lock: two
  # requests editing it at once would otherwise each make theirs, the last one
  # orphaning the copy of the first along with its edit.
  def find_and_ensure_exclusive_use(stable_id)
    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      next type_de_champ if exclusive_use?(type_de_champ)

      copy = type_de_champ.deep_clone do |original, kopy|
        ClonePiecesJustificativesService.clone_attachments(original, kopy)
        kopy.procedure = procedure
      end
      copy.save!
      self.type_de_champ_tree = type_de_champ_tree.replace(type_de_champ.stable_id, type_de_champ_id: copy.id, children: :keep)

      lay_out_type_de_champs(copy.id => copy).type_de_champ(stable_id)
    end
  end

  # Returns the type de champ as the draft lays it out once updated, or the one
  # holding the errors which kept it from being saved.
  #
  # A change of type follows the rules above. What a header section held
  # stays in its place.
  def update_type_de_champ(stable_id, params)
    params = params.to_h.with_indifferent_access

    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      type_champ = params[:type_champ].presence&.to_s
      changes_type = type_champ && type_champ != type_de_champ.type_champ

      # refused before a copy is made
      check_type_champ_change(type_de_champ, type_champ) if changes_type
      type_de_champ = find_and_ensure_exclusive_use(stable_id)

      type_de_champ = type_de_champ.becomes_type(type_champ) if changes_type

      # the editor form can submit options of another type (type change, or a
      # stale tab autosaving after one): the ones the type does not define are dropped
      if !type_de_champ.update(params.filter { |key, _| type_de_champ.respond_to?("#{key}=") })
        # the draft lays it out as it is saved, not as it failed to be
        lay_out_type_de_champs
        next type_de_champ
      end

      if changes_type
        self.type_de_champ_tree = type_de_champ_tree.replace(type_de_champ.stable_id, type_de_champ_id: type_de_champ.id, children: :inline)
        # of another class by now
        lay_out_type_de_champs
      end

      type_de_champ(stable_id)
    end
  end

  # The types a type de champ may take, its own included.
  def accepted_type_champs(type_de_champ)
    published_type_champ = procedure.published_revision&.type_de_champ(type_de_champ.stable_id)&.type_champ
    type_champs = if published_type_champ
      [published_type_champ, *CASTABLE_TYPE_CHAMPS.fetch(published_type_champ, [])].uniq
    else
      TypeDeChamp.type_champs.values
    end

    [type_de_champ.type_champ, *type_champs.filter { refusal_of_type_champ(type_de_champ, it).nil? }].uniq
  end

  # To the place given, as add_type_de_champ takes it, with what it holds.
  # Returns the type de champ as the draft lays it out by now.
  def move_type_de_champ(stable_id, parent_stable_id: nil, after_stable_id: nil)
    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      after = laid_out_type_de_champ(after_stable_id) if after_stable_id.present?
      parent = after ? after.parent : (laid_out_type_de_champ(parent_stable_id) if parent_stable_id.present?)

      refuse(:other_block, type_de_champ) if after && after.private? != type_de_champ.private?

      move(type_de_champ, parent:, after:)
    end
  end

  # Before its previous sibling. The first of a header section comes out of
  # it, right before. Left in place when first of its block.
  def move_up_type_de_champ(stable_id)
    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      previous = type_de_champ.previous_sibling

      if previous
        move(type_de_champ, parent: type_de_champ.parent, after: previous.previous_sibling)
      elsif type_de_champ.parent&.header_section?
        move(type_de_champ, parent: type_de_champ.parent.parent, after: type_de_champ.parent.previous_sibling)
      else
        type_de_champ
      end
    end
  end

  # After its next sibling. The last of a header section comes out of it,
  # right after. Left in place when last of its block.
  def move_down_type_de_champ(stable_id)
    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      following = type_de_champ.next_sibling

      if following
        move(type_de_champ, parent: type_de_champ.parent, after: following)
      elsif type_de_champ.parent&.header_section?
        move(type_de_champ, parent: type_de_champ.parent.parent, after: type_de_champ.parent)
      else
        type_de_champ
      end
    end
  end

  # Last of the header section right before it.
  def move_in_type_de_champ(stable_id)
    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      section = type_de_champ.previous_sibling
      refuse(:no_section_before, type_de_champ) if !section&.header_section?

      move(type_de_champ, parent: section, after: section.children.last)
    end
  end

  # Right after the header section holding it.
  def move_out_type_de_champ(stable_id)
    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      section = type_de_champ.parent
      refuse(:not_in_section, type_de_champ) if !section&.header_section?

      move(type_de_champ, parent: section.parent, after: section)
    end
  end

  # A header section takes the siblings following it, up to the next header
  # section, after what it holds already: what a title put in a flat list
  # stands for.
  def take_following_siblings(stable_id)
    edit_type_de_champs do
      section = laid_out_type_de_champ(stable_id)
      refuse(:holds_nothing, section) if !section.header_section?

      taken = section.siblings.drop(section.position + 1).take_while { !it.header_section? }
      taken.reduce(section.children.last) do |after, sibling|
        self.type_de_champ_tree = type_de_champ_tree.move(sibling.stable_id, parent: section.stable_id, after: after&.stable_id)
        sibling
      end

      type_de_champ(stable_id)
    end
  end

  # Returns the type de champ as the draft laid it out. It is left in the
  # database: it lives until the next publication (or reset) of the
  # procedure.
  def remove_type_de_champ(stable_id)
    edit_type_de_champs do
      type_de_champ = laid_out_type_de_champ(stable_id)
      removed = type_de_champ.repetition? ? [type_de_champ, *type_de_champ.flat_children] : [type_de_champ]
      removed.each { check_not_in_use(it, :remove) }

      self.type_de_champ_tree = type_de_champ_tree.remove(type_de_champ.stable_id, children: type_de_champ.header_section? ? :inline : :remove)

      type_de_champ
    end
  end

  # The suggestions of the LLM the administrateur accepted, applied as one
  # edit: one lock, the tree written once. A suggestion the rules refuse, or
  # whose type de champ is gone, is marked as failed: the others still apply.
  def apply_llm_rule_suggestion_items(changes)
    edit_type_de_champs do
      # the header sections added, by the id the LLM gave them
      added_stable_ids = {}

      changes.fetch(:add, []).each do |item|
        apply_llm_rule_suggestion_item(item) do |payload|
          parent_stable_id, after_stable_id = payload.values_at(:parent_stable_id, :after_stable_id).map { it&.negative? ? added_stable_ids.fetch(it) : it }
          section = add_type_de_champ(type_champ: TypeDeChamp.type_champs.fetch(:header_section), libelle: payload[:libelle], parent_stable_id:, after_stable_id:)
          raise RefusedError, section.errors.full_messages.to_sentence if !section.persisted?

          added_stable_ids[payload[:generated_stable_id]] = section.stable_id
        end
      end

      # once they are all there: a header section takes what follows it up to the next one
      added_stable_ids.each_value { take_following_siblings(it) }

      changes.fetch(:update, []).each do |item|
        apply_llm_rule_suggestion_item(item) do |payload|
          params = if payload.key?(:type_champ) # TypesImprover
            options = laid_out_type_de_champ(payload[:stable_id]).options.merge(payload[:options]) if payload[:options].present?
            { type_champ: payload[:type_champ], options: }.compact
          else # LabelImprover
            payload.slice(:libelle, :description).compact
          end

          updated = update_type_de_champ(payload[:stable_id], params)
          raise RefusedError, updated.errors.full_messages.to_sentence if updated.errors.any?
        end
      end

      changes.fetch(:destroy, []).each do |item|
        apply_llm_rule_suggestion_item(item) { remove_type_de_champ(item.stable_id) }
      end
    end
  end

  private

  def apply_llm_rule_suggestion_item(item)
    yield item.payload.with_indifferent_access
  rescue RefusedError, TypeDeChampTree::EditError, KeyError, ActiveRecord::RecordNotFound
    item.failed!
  end

  # RecordNotFound for a request replayed, or sent from a tab left behind: the
  # type de champ was removed since.
  def laid_out_type_de_champ(stable_id)
    type_de_champ(stable_id) || raise(ActiveRecord::RecordNotFound, "type de champ #{stable_id} is not laid out by the revision")
  end

  def exclusive_use?(type_de_champ)
    published_tree = procedure.published_revision&.type_de_champ_tree

    published_tree.nil? || published_tree.type_de_champ_ids.exclude?(type_de_champ.id)
  end

  def root_of(type_de_champ) = type_de_champ.private? ? :private : :public

  # the repetition whose block holds what a parent holds, nil for the form or the annotations
  def block_of_content(parent)
    return nil if parent.nil?

    parent.repetition? ? parent : parent.enclosing_repetition
  end

  def same_block?(type_de_champ, parent)
    return !type_de_champ.in_repetition? if parent.nil?

    parent.private? == type_de_champ.private? && block_of_content(parent) == type_de_champ.enclosing_repetition
  end

  # the header sections holding what a parent holds, within its block
  def section_level_in(parent)
    parent.nil? || parent.repetition? ? 0 : parent.block_level
  end

  # the levels of header sections a type de champ brings along
  def section_height(type_de_champ)
    return 0 if !type_de_champ.header_section?

    1 + type_de_champ.children.map { section_height(it) }.max.to_i
  end

  def move(type_de_champ, parent:, after:)
    check_holds(parent)
    refuse(:other_block, type_de_champ) if !same_block?(type_de_champ, parent)
    check_section_levels(parent, section_height(type_de_champ))

    self.type_de_champ_tree = type_de_champ_tree.move(type_de_champ.stable_id, parent: parent&.stable_id || root_of(type_de_champ), after: after&.stable_id)

    type_de_champ(type_de_champ.stable_id)
  end

  def check_holds(parent)
    refuse(:holds_nothing, parent) if parent && !parent.header_section? && !parent.repetition?
  end

  def check_section_levels(parent, height)
    refuse(:too_many_section_levels, nil, max: MAX_SECTION_LEVEL) if section_level_in(parent) + height > MAX_SECTION_LEVEL
  end

  def check_type_champ_allowed(type_champ, repetition:, private:)
    # left to the validations of the type de champ
    return if type_champ.blank?

    refusal = refusal_of_type_champ_in_block(type_champ, repetition:, private:)
    refuse(refusal, nil, type_champ: human_type_champ(type_champ)) if refusal
  end

  def refusal_of_type_champ_in_block(type_champ, repetition:, private:)
    return :unknown_type if !TypeDeChamp.type_champs.value?(type_champ)

    type = TypeDeChamp.find_sti_class(type_champ)

    if repetition && !type.allowed_in_repetition?
      :not_allowed_in_repetition
    elsif private ? type.public_only? : type.private_only?
      :not_allowed_on_this_side
    end
  end

  # nil when the type de champ may take the type, where it sits
  def refusal_of_type_champ(type_de_champ, type_champ)
    refusal = refusal_of_type_champ_in_block(type_champ, repetition: type_de_champ.enclosing_repetition, private: type_de_champ.private?)
    return refusal if refusal

    :too_many_section_levels if type_champ == TypeDeChamp.type_champs.fetch(:header_section) && section_level_in(type_de_champ.parent) >= MAX_SECTION_LEVEL
  end

  def check_type_champ_change(type_de_champ, type_champ)
    check_not_in_use(type_de_champ, :change_type)
    refusal = refusal_of_type_champ(type_de_champ, type_champ)
    refuse(refusal, type_de_champ, type_champ: human_type_champ(type_champ), max: MAX_SECTION_LEVEL) if refusal
    refuse(:type_not_accepted, type_de_champ, type_champ: human_type_champ(type_champ)) if accepted_type_champs(type_de_champ).exclude?(type_champ)
    # a repetition holding types de champ
    raise RefusedError, type_de_champ.type_change_locked_message if type_de_champ.type_change_locked?
  end

  def check_not_in_use(type_de_champ, edit)
    return if !type_de_champ.type_champ_locked?

    raise RefusedError, edit == :remove ? type_de_champ.deletion_locked_message : type_de_champ.type_change_locked_message
  end

  def refuse(reason, type_de_champ = nil, **)
    raise RefusedError, I18n.t(reason, scope: 'activerecord.errors.models.procedure_revision.edit', libelle: type_de_champ&.libelle, **)
  end

  def human_type_champ(type_champ)
    I18n.t(type_champ, scope: 'activerecord.attributes.type_de_champ.type_champs', default: type_champ.to_s, app_name: APPLICATION_NAME)
  end
end
