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
  end

  private

  def add_errors(record, attribute, message, tags)
    if tags.present?
      record.errors.add(attribute, message, count: tags.size, tags: tags.join(', '))
    end
  end

  def invalid_tags_for_revision(record, tags, revision)
    revision_stable_ids = (revision.root_types_de_champ_public + revision.root_types_de_champ_private)
      .map(&:stable_id)
      .uniq

    tags.filter_map do |(tag, stable_id)|
      if stable_id.present? && !stable_id.in?(revision_stable_ids)
        tag
      end
    end
  end
end
