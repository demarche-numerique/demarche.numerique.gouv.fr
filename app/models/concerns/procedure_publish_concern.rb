# frozen_string_literal: true

module ProcedurePublishConcern
  extend ActiveSupport::Concern

  def publish_or_reopen!(administrateur, path)
    new_revision = false
    transaction do
      if brouillon?
        reset!
      elsif draft_changed?
        new_revision = true
        publish_new_revision(administrateur)
      end

      other_procedure = other_procedure_with_path(path)
      claim_path!(administrateur, path)
      if other_procedure.present?
        other_procedure.unpublish! if other_procedure.may_unpublish?

        # may_publish? is false on replay: the procedure is already publiee
        publish!(administrateur, other_procedure.canonical_procedure || other_procedure) if may_publish?
      elsif may_publish?
        publish!(administrateur, nil)
      end
    end

    if new_revision
      dossiers
        .state_not_termine
        .find_each(&:rebase_later)
    end
  end

  def publish_revision!(administrateur)
    reset!

    transaction { publish_new_revision(administrateur) }

    dossiers
      .state_not_termine
      .find_each(&:rebase_later)
  end

  def reset_draft_revision!
    if published_revision.present? && draft_changed?
      reset!
      transaction do
        draft_revision.type_de_champs.filter(&:only_present_on_draft?).each(&:destroy)
        draft_revision.update(dossier_submitted_message: nil)
        draft_revision.destroy
        update!(draft_revision: create_new_revision(published_revision))
      end
    end
  end

  def reset!
    if !locked? || draft_changed?
      dossier_ids_to_destroy = draft_revision.dossiers.ids
      if dossier_ids_to_destroy.present?
        Rails.logger.info("Resetting #{dossier_ids_to_destroy.size} dossiers on procedure #{id}: #{dossier_ids_to_destroy}")
        draft_revision.dossiers.destroy_all
      end
    end
  end

  def before_publish
    assign_attributes(closed_at: nil, unpublished_at: nil)
  end

  def after_publish(administrateur, canonical_procedure = nil)
    self.canonical_procedure = canonical_procedure

    touch(:published_at)
    publish_new_revision(administrateur)
  end

  def after_republish(administrateur, canonical_procedure = nil)
    touch(:published_at)
  end

  def after_close
    touch(:closed_at)
  end

  def after_unpublish
    touch(:unpublished_at)
  end

  def create_new_revision(revision = nil)
    transaction do
      new_revision = (revision || draft_revision)
        .deep_clone(include: [:revision_type_de_champs], except: [:type_de_champ_tree])
        .tap { |revision| revision.published_at = nil }
        .tap { |revision| revision.administrateur_id = nil }
        .tap(&:save!)

      move_new_children_to_new_parent_coordinate(new_revision)

      new_revision
    end
  end

  private

  def publish_new_revision(administrateur)
    # the last edit of the draft: the tree it leaves is the published one, and
    # the lock, held until publication commits, keeps the editor from changing
    # the coordinates before the next draft is cloned from them
    draft_revision.edit_type_de_champs do
      cleanup_type_de_champs_options!
      cleanup_type_de_champs_children!
      nullify_unused_referentiels
    end
    self.published_revision = draft_revision
    self.draft_revision = create_new_revision
    save!(context: :publication)
    published_revision.update_columns(published_at: Time.current, administrateur_id: administrateur.id)
  end

  def move_new_children_to_new_parent_coordinate(new_draft)
    children = new_draft.revision_type_de_champs
      .includes(parent: :type_de_champ)
      .where.not(parent_id: nil)
    coordinates_by_stable_id = new_draft.revision_type_de_champs
      .includes(:type_de_champ)
      .index_by(&:stable_id)

    children.each do |child|
      child.update!(parent: coordinates_by_stable_id.fetch(child.parent.stable_id))
    end
    new_draft.reload
  end

  def cleanup_type_de_champs_options!
    draft_revision.type_de_champs.each do |type_de_champ|
      type_de_champ.update!(options: type_de_champ.clean_options)
    end
  end

  def cleanup_type_de_champs_children!
    draft_revision.revision_type_de_champs
      .filter(&:orphan?)
      .each { draft_revision.remove_type_de_champ(_1.stable_id) }
  end

  def nullify_unused_referentiels
    draft_revision.type_de_champs
      .reject { _1.drop_down_list? || _1.multiple_drop_down_list? || _1.referentiel? }
      .each do |type_de_champ|
        type_de_champ.update!(referentiel_id: nil)
      end
  end
end
