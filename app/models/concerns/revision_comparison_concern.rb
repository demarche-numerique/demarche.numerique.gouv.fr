# frozen_string_literal: true

module RevisionComparisonConcern
  extend ActiveSupport::Concern

  def compare_type_de_champs(to_revision)
    return [] if self == to_revision

    from_h = type_de_champs.index_by(&:stable_id)
    to_h = to_revision.type_de_champs.index_by(&:stable_id)

    from_sids = from_h.keys
    to_sids = to_h.keys

    removed = (from_sids - to_sids).map { ProcedureRevisionChange::RemoveChamp.new(from_h[_1]) }
    added = (to_sids - from_sids).map { ProcedureRevisionChange::AddChamp.new(to_h[_1]) }

    kept = from_sids.intersection(to_sids)

    from_positions = type_de_champ_positions(self)
    to_positions = type_de_champ_positions(to_revision)

    moved = kept
      .filter { from_positions[_1] != to_positions[_1] }
      .map { ProcedureRevisionChange::MoveChamp.new(from_h[_1], from_positions[_1], to_positions[_1]) }

    preload_diffed_attachments(kept.flat_map { [from_h[_1], to_h[_1]] })

    changed = kept
      .map { [from_h[_1], to_h[_1]] }
      .flat_map { |from, to| compare_type_de_champ(from, to, to_revision) }

    (removed + added + moved + changed).sort_by { _1.op == :remove ? from_sids.index(_1.stable_id) : to_sids.index(_1.stable_id) }
  end

  def compare_ineligibilite_rules(new_revision)
    from_ineligibilite_rules = ineligibilite_rules
    to_ineligibilite_rules = new_revision.ineligibilite_rules
    changes = []

    if from_ineligibilite_rules.present? && to_ineligibilite_rules.blank?
      changes << ProcedureRevisionChange::RemoveEligibiliteRuleChange
    elsif from_ineligibilite_rules.blank? && to_ineligibilite_rules.present?
      changes << ProcedureRevisionChange::AddEligibiliteRuleChange
    elsif from_ineligibilite_rules != to_ineligibilite_rules
      changes << ProcedureRevisionChange::UpdateEligibiliteRuleChange
    end
    if ineligibilite_message != new_revision.ineligibilite_message
      changes << ProcedureRevisionChange::UpdateEligibiliteMessageChange
    end
    if ineligibilite_enabled != new_revision.ineligibilite_enabled
      changes << (new_revision.ineligibilite_enabled ? ProcedureRevisionChange::EligibiliteEnabledChange : ProcedureRevisionChange::EligibiliteDisabledChange)
    end
    changes.map { _1.new(self, new_revision) }
  end

  private

  # The position of every type de champ, by stable id, in the list it is moved
  # within: the content of its repetition, or the public (or private) types de
  # champ out of any repetition, header sections and their content alike.
  def type_de_champ_positions(revision)
    lists = [revision.public_root_type_de_champs, revision.private_root_type_de_champs]
    lists += revision.type_de_champs.filter(&:repetition?).map(&:flat_children)

    lists.flat_map { |type_de_champs| type_de_champs.each_with_index.map { |type_de_champ, position| [type_de_champ.stable_id, position] } }.to_h
  end

  # The files TypeDeChamp#revision_diff_attributes reads, loaded at once where
  # each type de champ would run its own queries.
  def preload_diffed_attachments(type_de_champs)
    { piece_justificative_template_attachment: :piece_justificative?, notice_explicative_attachment: :explication? }.each do |association, predicate|
      ActiveRecord::Associations::Preloader.new(records: type_de_champs.filter(&predicate), associations: { association => :blob }).call
    end
  end

  # Diffs two versions of a type de champ over the attributes it declares in
  # TypeDeChamp#revision_diff_attributes. The keys of the new version drive
  # the comparison: when the type changed, the old version is read as the new
  # type so that both sides expose the same options.
  def compare_type_de_champ(from_type_de_champ, to_type_de_champ, to_revision)
    changes = []

    if from_type_de_champ.type_champ != to_type_de_champ.type_champ
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ, :type_champ, from_type_de_champ.type_champ, to_type_de_champ.type_champ)
      from_type_de_champ = from_type_de_champ.becomes_type(to_type_de_champ.type_champ)
    end

    from_values = from_type_de_champ.revision_diff_attributes(self)
    to_values = to_type_de_champ.revision_diff_attributes(to_revision)

    to_values.each do |attribute, to_value|
      from_value = from_values[attribute]
      next if TypeDeChamp::RevisionDiffValue.key_of(from_value) == TypeDeChamp::RevisionDiffValue.key_of(to_value)

      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        attribute,
        TypeDeChamp::RevisionDiffValue.report_of(from_value),
        TypeDeChamp::RevisionDiffValue.report_of(to_value))
    end

    changes
  end
end
