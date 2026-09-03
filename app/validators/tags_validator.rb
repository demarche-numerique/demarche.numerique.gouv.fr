# frozen_string_literal: true

class TagsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    procedure = record.procedure
    tags = record.used_type_de_champ_tags(value)

    invalid_tags = tags.filter_map do |(tag, stable_id)|
      tag if stable_id.nil?
    end

    invalid_for_draft_revision = invalid_tags_for_revision(record, tags, procedure.draft_revision)

    invalid_for_published_revision = if procedure.published_revision_id.present?
      invalid_tags_for_revision(record, tags, procedure.published_revision)
    else
      []
    end

    invalid_for_previous_revision = procedure
      .revisions_with_pending_dossiers
      .flat_map do |revision|
        invalid_tags_for_revision(record, tags, revision)
      end.uniq

    # champ is added in draft revision but not yet published
    champ_missing_in_published_revision = (invalid_for_published_revision - invalid_for_draft_revision)
    add_errors(record, attribute, :champ_missing_in_published_revision, champ_missing_in_published_revision)

    # champ is removed but the removal is not yet published
    champ_missing_in_draft_revision = (invalid_for_draft_revision - invalid_for_published_revision)
    add_errors(record, attribute, :champ_missing_in_draft_revision, champ_missing_in_draft_revision)

    # champ is removed and the removal is published
    champ_missing_in_published_and_draft_revision = invalid_for_published_revision.intersection(invalid_for_draft_revision)
    add_errors(record, attribute, :champ_missing_in_published_and_draft_revision, champ_missing_in_published_and_draft_revision)

    # champ is missing from one of the revisions in pending dossiers
    add_errors(record, attribute, :champ_missing_in_previous_revision, invalid_for_previous_revision)

    # unknown champ
    add_errors(record, attribute, :champ_missing, invalid_tags)

    # champ rendered as a list, placed where a list cannot be rendered
    add_errors(record, attribute, :block_tag_in_heading, block_tags_in_headings(record, value))
  end

  private

  # Tiptap node types whose HTML element cannot contain a list; the editor
  # enforces the same rule (see app/javascript/shared/tiptap/block_tags.ts).
  INLINE_ONLY_NODE_TYPES = ['title', 'heading'].freeze

  def block_tags_in_headings(record, value)
    return [] unless value.respond_to?(:deconstruct_keys)

    mentions = TiptapService.mentions_within(value.deep_symbolize_keys, INLINE_ONLY_NODE_TYPES)
    return [] if mentions.empty?

    block_tag_ids = record.block_level_tag_ids
    mentions.filter_map { |(id, label)| label if id.in?(block_tag_ids) }.uniq
  end

  def add_errors(record, attribute, message, tags)
    if tags.present?
      record.errors.add(attribute, message, count: tags.size, tags: tags.join(', '))
    end
  end

  def invalid_tags_for_revision(record, tags, revision)
    revision_stable_ids = revision
      .revision_type_de_champs
      .filter { !_1.child? }
      .map(&:stable_id)
      .uniq

    tags.filter_map do |(tag, stable_id)|
      if stable_id.present? && !stable_id.in?(revision_stable_ids)
        tag
      end
    end
  end
end
