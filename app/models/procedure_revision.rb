# frozen_string_literal: true

class ProcedureRevision < ApplicationRecord
  include Logic
  include RevisionDescribableToLLMConcern
  self.implicit_order_column = :created_at
  belongs_to :administrateur, optional: true
  belongs_to :procedure, -> { with_discarded }, inverse_of: :revisions, optional: false
  belongs_to :dossier_submitted_message, inverse_of: :revisions, optional: true, dependent: :destroy
  has_many :llm_rule_suggestions, dependent: :destroy, inverse_of: :procedure_revision
  has_many :dossiers, inverse_of: :revision, foreign_key: :revision_id
  has_many :revision_types_de_champ, -> { order(:position, :id) }, class_name: 'ProcedureRevisionTypeDeChamp', foreign_key: :revision_id, dependent: :destroy, inverse_of: :revision

  def revision_types_de_champ_public = revision_types_de_champ.filter { _1.root? && _1.public? }.sort_by(&:position)
  def revision_types_de_champ_private = revision_types_de_champ.filter { _1.root? && _1.private? }.sort_by(&:position)
  def types_de_champ = revision_types_de_champ.map(&:type_de_champ)
  def types_de_champ_public = revision_types_de_champ_public.map(&:type_de_champ)
  def types_de_champ_private = revision_types_de_champ_private.map(&:type_de_champ)

  has_one :draft_procedure, -> { with_discarded }, class_name: 'Procedure', foreign_key: :draft_revision_id, dependent: :nullify, inverse_of: :draft_revision
  has_one :published_procedure, -> { with_discarded }, class_name: 'Procedure', foreign_key: :published_revision_id, dependent: :nullify, inverse_of: :published_revision

  scope :ordered, -> { order(:created_at) }

  validates :ineligibilite_message, presence: true, if: -> { ineligibilite_enabled? }

  delegate :path, to: :procedure, prefix: true

  validate :ineligibilite_rules_are_valid?,
    on: [:ineligibilite_rules_editor, :publication]
  validates :ineligibilite_message,
    presence: true,
    if: -> { ineligibilite_enabled? },
    on: [:ineligibilite_rules_editor, :publication]
  validates :ineligibilite_rules,
    presence: true,
    if: -> { ineligibilite_enabled? },
    on: [:ineligibilite_rules_editor, :publication]

  serialize :ineligibilite_rules, coder: LogicSerializer

  def add_type_de_champ(params)
    parent_stable_id = params.delete(:parent_stable_id)
    parent_coordinate, _ = coordinate_and_tdc(parent_stable_id)
    parent_id = parent_coordinate&.id

    after_stable_id = params.delete(:after_stable_id)
    after_coordinate, _ = coordinate_and_tdc(after_stable_id)

    type_de_champ = TypeDeChamp.new(params)

    if params[:private].to_s == "true"
      type_de_champ.mandatory = false
    end

    if type_de_champ.save
      siblings = siblings_for(type_de_champ:, parent_coordinate:)
      position = next_position_for(after_coordinate:)

      transaction do
        # moving all the impacted tdc down
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..).update_all("position = position + 1")

        # insertion of the new tdc
        revision_types_de_champ.create!(type_de_champ:, parent_id:, position:)
      end

      revision_types_de_champ.reset
    end

    type_de_champ
  rescue => e
    TypeDeChamp.new.tap { _1.errors.add(:base, e.message) }
  end

  def find_and_ensure_exclusive_use(stable_id)
    coordinate, tdc = coordinate_and_tdc(stable_id)

    if tdc.only_present_on_draft?
      tdc
    else
      replace_type_de_champ_by_clone(coordinate)
    end
  end

  def move_type_de_champ(stable_id, position)
    coordinate, _ = coordinate_and_tdc(stable_id)
    siblings = coordinate.siblings

    transaction do
      if position > coordinate.position
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).update_all("position = position - 1")
      else
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: position..coordinate.position).update_all("position = position + 1")
      end
      coordinate.update_column(:position, position)
    end

    revision_types_de_champ.reset
    coordinate.reload
    coordinate
  end

  def move_type_de_champ_after(stable_id, position)
    coordinate, _ = coordinate_and_tdc(stable_id)
    siblings = coordinate.siblings

    transaction do
      if position > coordinate.position
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: coordinate.position..position).update_all("position = position - 1")
        coordinate.update_column(:position, position)
      else
        ProcedureRevisionTypeDeChamp.where(id: siblings, position: (position + 1)...coordinate.position).update_all("position = position + 1")
        coordinate.update_column(:position, position + 1)
      end
    end

    revision_types_de_champ.reset
    coordinate.reload
    coordinate
  end

  def remove_type_de_champ(stable_id)
    coordinate, tdc = coordinate_and_tdc(stable_id)

    # in case of replay
    return nil if coordinate.nil?

    children = children_of(tdc).to_a

    transaction do
      coordinate.destroy

      children.each(&:destroy_if_orphan)
      tdc.destroy_if_orphan

      ProcedureRevisionTypeDeChamp.where(id: coordinate.siblings, position: coordinate.position..).update_all("position = position - 1")
    end

    revision_types_de_champ.reset
    coordinate
  end

  def move_up_type_de_champ(stable_id)
    coordinate, _ = coordinate_and_tdc(stable_id)

    if coordinate.position > 0
      move_type_de_champ(stable_id, coordinate.position - 1)
    else
      coordinate
    end
  end

  def move_down_type_de_champ(stable_id)
    coordinate, _ = coordinate_and_tdc(stable_id)

    move_type_de_champ(stable_id, coordinate.position + 1)
  end

  def draft?
    procedure.draft_revision_id == id
  end

  def locked?
    !draft?
  end

  def compare_types_de_champ(revision)
    changes = []
    changes += compare_revision_types_de_champ(revision_types_de_champ, revision.revision_types_de_champ)
    changes
  end

  def compare_ineligibilite_rules(revision)
    changes = []
    changes += compare_revision_ineligibilite_rules(revision)
    changes
  end

  def types_de_champ_for(scope: nil)
    case scope
    when :public
      types_de_champ.filter(&:public?)
    when :private
      types_de_champ.filter(&:private?)
    else
      types_de_champ
    end
  end

  def children_of(tdc)
    coordinate_for(tdc).types_de_champ
  end

  def parent_of(tdc)
    coordinate = coordinate_for(tdc)
    if coordinate&.child?
      revision_types_de_champ.find { _1.id == coordinate.parent_id }&.type_de_champ
    end
  end

  def dependent_conditions(tdc)
    stable_id = tdc.stable_id

    (tdc.public? ? types_de_champ_public : types_de_champ_private).filter do |other_tdc|
      next if !other_tdc.condition?

      other_tdc.condition.sources.include?(stable_id)
    end
  end

  # Estimated duration to fill the form, in seconds.
  #
  # If the revision is locked (i.e. published), the result is cached (because type de champs can no longer be mutated).
  def estimated_fill_duration
    Rails.cache.fetch("#{cache_key_with_version}/estimated_fill_duration", expires_in: 12.hours, force: !locked?) do
      compute_estimated_fill_duration
    end
  end

  def coordinate_for(tdc)
    revision_types_de_champ.find { _1.stable_id == tdc.stable_id }
  end

  def carte?
    types_de_champ_public.any?(&:carte?)
  end

  def coordinate_and_tdc(stable_id)
    return [nil, nil] if stable_id.blank?

    coordinate = revision_types_de_champ
      .joins(:type_de_champ)
      .find_by(type_de_champ: { stable_id: stable_id })

    [coordinate, coordinate&.type_de_champ]
  end

  def simple_routable_types_de_champ
    types_de_champ_public.filter(&:simple_routable?)
  end

  def conditionable_types_de_champ
    types_de_champ_for(scope: :public).filter(&:conditionable?)
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
          coordinate = move_type_de_champ(stable_id, 0)
          if payload.key?(:header_section_level) && coordinate.type_de_champ.header_section? && params.present?
            coordinate.type_de_champ.update(params)
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

          after_coordinate, _ = coordinate_and_tdc(after_stable_id)
          if after_coordinate
            coordinate = move_type_de_champ_after(stable_id, after_coordinate.position)
            if payload.key?(:header_section_level) && coordinate.type_de_champ.header_section? && params.present?
              coordinate.type_de_champ.update(params)
            end
          end
        end
      elsif payload.key?(:type_champ) # TypesImprover: type change
        stable_id, type_champ, options = payload.values_at(:stable_id, :type_champ, :options)

        tdc = find_and_ensure_exclusive_use(stable_id)
        update_params = { type_champ: }
        update_params[:options] = tdc.options.merge(options) if options.present?
        tdc.update(update_params)
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

  private

  def compute_estimated_fill_duration
    types_de_champ_public.sum do |tdc|
      next tdc.estimated_read_duration unless tdc.fillable?

      duration = tdc.estimated_read_duration + tdc.estimated_fill_duration(self)
      duration /= 2 unless tdc.mandatory?

      duration
    end
  end

  def siblings_for(type_de_champ:, parent_coordinate: nil)
    if parent_coordinate
      parent_coordinate.revision_types_de_champ
    elsif type_de_champ.private?
      revision_types_de_champ_private
    else
      revision_types_de_champ_public
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

  def compare_revision_types_de_champ(from_coordinates, to_coordinates)
    if from_coordinates == to_coordinates
      []
    else
      from_h = from_coordinates.index_by(&:stable_id)
      to_h = to_coordinates.index_by(&:stable_id)

      from_sids = from_h.keys
      to_sids = to_h.keys

      removed = (from_sids - to_sids).map { ProcedureRevisionChange::RemoveChamp.new(from_h[_1]) }
      added = (to_sids - from_sids).map { ProcedureRevisionChange::AddChamp.new(to_h[_1]) }

      kept = from_sids.intersection(to_sids)

      moved = kept
        .map { [from_h[_1], to_h[_1]] }
        .filter { |from, to| from.position != to.position }
        .map { |from, to| ProcedureRevisionChange::MoveChamp.new(from, from.position, to.position) }

      changed = kept
        .map { [from_h[_1], to_h[_1]] }
        .flat_map { |from, to| compare_type_de_champ(from.type_de_champ, to.type_de_champ, from_coordinates, to_coordinates) }

      (removed + added + moved + changed).sort_by { _1.op == :remove ? from_sids.index(_1.stable_id) : to_sids.index(_1.stable_id) }
    end
  end

  def compare_revision_ineligibilite_rules(new_revision)
    from_ineligibilite_rules = ineligibilite_rules
    to_ineligibilite_rules = new_revision.ineligibilite_rules
    changes = []

    if from_ineligibilite_rules.present? && to_ineligibilite_rules.blank?
      changes << ProcedureRevisionChange::RemoveEligibiliteRuleChange
    end
    if from_ineligibilite_rules.blank? && to_ineligibilite_rules.present?
      changes << ProcedureRevisionChange::AddEligibiliteRuleChange
    end
    if from_ineligibilite_rules != to_ineligibilite_rules
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

  def compare_type_de_champ(from_type_de_champ, to_type_de_champ, from_coordinates, to_coordinates)
    changes = []
    if from_type_de_champ.type_champ != to_type_de_champ.type_champ
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :type_champ,
        from_type_de_champ.type_champ,
        to_type_de_champ.type_champ)
    end
    if from_type_de_champ.libelle != to_type_de_champ.libelle
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :libelle,
        from_type_de_champ.libelle,
        to_type_de_champ.libelle)
    end
    if from_type_de_champ.collapsible_explanation_enabled? != to_type_de_champ.collapsible_explanation_enabled?
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :collapsible_explanation_enabled,
        from_type_de_champ.collapsible_explanation_enabled?,
        to_type_de_champ.collapsible_explanation_enabled?)
    end
    if from_type_de_champ.collapsible_explanation_text != to_type_de_champ.collapsible_explanation_text
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :collapsible_explanation_text,
        from_type_de_champ.collapsible_explanation_text,
        to_type_de_champ.collapsible_explanation_text)
    end
    if from_type_de_champ.description != to_type_de_champ.description
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :description,
        from_type_de_champ.description,
        to_type_de_champ.description)
    end
    if from_type_de_champ.mandatory? != to_type_de_champ.mandatory?
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :mandatory,
        from_type_de_champ.mandatory?,
        to_type_de_champ.mandatory?)
    end

    if from_type_de_champ.condition != to_type_de_champ.condition
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :condition,
        from_type_de_champ.condition&.to_s(from_coordinates.map(&:type_de_champ)),
        to_type_de_champ.condition&.to_s(to_coordinates.map(&:type_de_champ)))
    end

    if to_type_de_champ.any_drop_down_list?
      if from_type_de_champ.drop_down_mode != to_type_de_champ.drop_down_mode
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :drop_down_mode,
          from_type_de_champ.drop_down_mode,
          to_type_de_champ.drop_down_mode)
      end

      if to_type_de_champ.drop_down_advanced?
        if from_type_de_champ.referentiel_id != to_type_de_champ.referentiel_id
          changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
            :referentiel,
            from_type_de_champ.referentiel_id,
            to_type_de_champ.referentiel_id)
        end
      else
        from_drop_down_options = from_type_de_champ.drop_down_advanced? ? [] : from_type_de_champ.drop_down_options
        if from_drop_down_options != to_type_de_champ.drop_down_options
          changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
            :drop_down_options,
            from_drop_down_options,
            to_type_de_champ.drop_down_options)
        end
      end

      if to_type_de_champ.linked_drop_down_list?
        if from_type_de_champ.drop_down_secondary_libelle != to_type_de_champ.drop_down_secondary_libelle
          changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
            :drop_down_secondary_libelle,
            from_type_de_champ.drop_down_secondary_libelle,
            to_type_de_champ.drop_down_secondary_libelle)
        end
        if from_type_de_champ.drop_down_secondary_description != to_type_de_champ.drop_down_secondary_description
          changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
            :drop_down_secondary_description,
            from_type_de_champ.drop_down_secondary_description,
            to_type_de_champ.drop_down_secondary_description)
        end
      end

      if from_type_de_champ.drop_down_other? != to_type_de_champ.drop_down_other?
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :drop_down_other,
          from_type_de_champ.drop_down_other?,
          to_type_de_champ.drop_down_other?)
      end
    elsif to_type_de_champ.carte?
      if from_type_de_champ.carte_optional_layers != to_type_de_champ.carte_optional_layers
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :carte_layers,
          from_type_de_champ.carte_optional_layers,
          to_type_de_champ.carte_optional_layers)
      end
    elsif to_type_de_champ.piece_justificative_or_titre_identite?
      if from_type_de_champ.checksum_for_attachment(:piece_justificative_template) != to_type_de_champ.checksum_for_attachment(:piece_justificative_template)
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :piece_justificative_template,
          from_type_de_champ.filename_for_attachement(:piece_justificative_template),
          to_type_de_champ.filename_for_attachement(:piece_justificative_template))
      end
      if from_type_de_champ.nature != to_type_de_champ.nature
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :nature,
          from_type_de_champ.nature,
          to_type_de_champ.nature)
      end

      if !(to_type_de_champ.titre_identite_nature? || from_type_de_champ.titre_identite_nature? || to_type_de_champ.rib_nature? || from_type_de_champ.rib_nature?)
        if from_type_de_champ.pj_limit_formats != to_type_de_champ.pj_limit_formats
          changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
            :pj_limit_formats,
            from_type_de_champ.pj_limit_formats,
            to_type_de_champ.pj_limit_formats)
        end
        if Array.wrap(from_type_de_champ.pj_format_families) != Array.wrap(to_type_de_champ.pj_format_families)
          changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
            :pj_format_families,
            from_type_de_champ.pj_format_families,
            to_type_de_champ.pj_format_families)
        end
        if from_type_de_champ.pj_auto_purge != to_type_de_champ.pj_auto_purge
          changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
            :pj_auto_purge,
            from_type_de_champ.pj_auto_purge,
            to_type_de_champ.pj_auto_purge)
        end
      end
    elsif to_type_de_champ.explication?
      if from_type_de_champ.checksum_for_attachment(:notice_explicative) != to_type_de_champ.checksum_for_attachment(:notice_explicative)
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :notice_explicative,
          from_type_de_champ.filename_for_attachement(:notice_explicative),
          to_type_de_champ.filename_for_attachement(:notice_explicative))
      end
    elsif to_type_de_champ.textarea?
      if from_type_de_champ.character_limit.presence != to_type_de_champ.character_limit.presence
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :character_limit,
          from_type_de_champ.character_limit,
          to_type_de_champ.character_limit)
      end
    elsif to_type_de_champ.integer_number? || to_type_de_champ.decimal_number?
      if from_type_de_champ.positive_number != to_type_de_champ.positive_number
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :positive_number,
          from_type_de_champ.positive_number,
          to_type_de_champ.positive_number)
      end
      if from_type_de_champ.range_number != to_type_de_champ.range_number
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :range_number,
          from_type_de_champ.range_number,
          to_type_de_champ.range_number)
      end
      if from_type_de_champ.min_number != to_type_de_champ.min_number
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :min_number,
          from_type_de_champ.min_number,
          to_type_de_champ.min_number)
      end
      if from_type_de_champ.max_number != to_type_de_champ.max_number
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :max_number,
          from_type_de_champ.max_number,
          to_type_de_champ.max_number)
      end
    elsif to_type_de_champ.formatted?
      if from_type_de_champ.expression_reguliere != to_type_de_champ.expression_reguliere
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :expression_reguliere,
          from_type_de_champ.expression_reguliere,
          to_type_de_champ.expression_reguliere)
      end
      if from_type_de_champ.expression_reguliere_indications != to_type_de_champ.expression_reguliere_indications
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :expression_reguliere_indications,
          from_type_de_champ.expression_reguliere_indications,
          to_type_de_champ.expression_reguliere_indications)
      end
      if from_type_de_champ.expression_reguliere_exemple_text != to_type_de_champ.expression_reguliere_exemple_text
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :expression_reguliere_exemple_text,
          from_type_de_champ.expression_reguliere_exemple_text,
          to_type_de_champ.expression_reguliere_exemple_text)
      end
      if from_type_de_champ.expression_reguliere_error_message != to_type_de_champ.expression_reguliere_error_message
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :expression_reguliere_error_message,
          from_type_de_champ.expression_reguliere_error_message,
          to_type_de_champ.expression_reguliere_error_message)
      end
      if from_type_de_champ.formatted_mode != to_type_de_champ.formatted_mode
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :formatted_mode,
          from_type_de_champ.formatted_mode,
          to_type_de_champ.formatted_mode)
      end
      if from_type_de_champ.letters_accepted != to_type_de_champ.letters_accepted
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :letters_accepted,
          from_type_de_champ.letters_accepted,
          to_type_de_champ.letters_accepted)
      end
      if from_type_de_champ.numbers_accepted != to_type_de_champ.numbers_accepted
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :numbers_accepted,
          from_type_de_champ.numbers_accepted,
          to_type_de_champ.numbers_accepted)
      end
      if from_type_de_champ.special_characters_accepted != to_type_de_champ.special_characters_accepted
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :special_characters_accepted,
          from_type_de_champ.special_characters_accepted,
          to_type_de_champ.special_characters_accepted)
      end
      if from_type_de_champ.min_character_length != to_type_de_champ.min_character_length
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :min_character_length,
          from_type_de_champ.min_character_length,
          to_type_de_champ.min_character_length)
      end
      if from_type_de_champ.max_character_length != to_type_de_champ.max_character_length
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          :max_character_length,
          from_type_de_champ.max_character_length,
          to_type_de_champ.max_character_length)
      end
    elsif to_type_de_champ.referentiel?
      compare_referentiel_changes(from_type_de_champ, to_type_de_champ).each do |change|
        changes << change
      end
    end
    changes
  end

  def compare_referentiel_changes(from_type_de_champ, to_type_de_champ)
    changes = []
    from_referentiel = from_type_de_champ.referentiel
    to_referentiel = to_type_de_champ.referentiel

    [:url, :mode, :hint, :test_data].each do |field|
      if from_referentiel&.send(field) != to_referentiel&.send(field)
        changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
          "referentiel_#{field}".to_sym,
          from_referentiel&.send(field),
          to_referentiel&.send(field))
      end
    end

    if from_type_de_champ.referentiel_mapping != to_type_de_champ.referentiel_mapping
      changes << ProcedureRevisionChange::UpdateChamp.new(from_type_de_champ,
        :referentiel_mapping,
        from_type_de_champ.referentiel_mapping,
        to_type_de_champ.referentiel_mapping)
    end

    changes
  end

  def ineligibilite_rules_are_valid?
    return unless ineligibilite_rules

    rules_errors = ineligibilite_rules.errors(types_de_champ_for(scope: :public).to_a)

    if rules_errors.any? || ineligibilite_rules.type == :empty
      errors.add(:ineligibilite_rules, :invalid)
    end
  end

  def replace_type_de_champ_by_clone(coordinate)
    transaction do
      cloned_type_de_champ = coordinate.type_de_champ.deep_clone do |original, kopy|
        ClonePiecesJustificativesService.clone_attachments(original, kopy)
      end
      coordinate.update!(type_de_champ: cloned_type_de_champ)
      cloned_type_de_champ
    end
  end
end
