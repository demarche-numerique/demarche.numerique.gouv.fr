# frozen_string_literal: true

# Edits the draft revision of a procedure on behalf of a programmatic client
# (GraphQL mutations, MCP tools): the operations of the types de champ editor,
# with its guards, without its views.
#
# Every operation works on stable ids and returns a Result: the stable id of
# the type de champ it touched, or the reasons it was refused, worded for the
# administrateur (or the assistant) to act on. Nothing is ever published from
# here: the draft is the only revision written.
class DraftEditorService
  Result = Data.define(:stable_id, :errors) do
    def self.success(stable_id) = new(stable_id: stable_id.to_s, errors: [])
    def self.failure(*errors) = new(stable_id: nil, errors: errors.flatten)

    def success? = errors.empty?
  end

  # The names a client gives the operators of a condition: 'eq', 'not_eq',
  # 'greater_than', 'include', 'in_departement'…
  OPERATORS = [
    Logic::Eq,
    Logic::NotEq,
    Logic::GreaterThan,
    Logic::GreaterThanEq,
    Logic::LessThan,
    Logic::LessThanEq,
    Logic::IncludeOperator,
    Logic::ExcludeOperator,
    Logic::InDepartementOperator,
    Logic::NotInDepartementOperator,
    Logic::InRegionOperator,
    Logic::NotInRegionOperator,
  ].index_by { it.name.demodulize.underscore.delete_suffix('_operator') }.freeze

  OPERATOR_NAMES = OPERATORS.transform_values(&:name).invert.freeze

  TOP_OPERATORS = { 'and' => Logic::And, 'or' => Logic::Or }.freeze

  # Options the editor form does not offer either: internal switches, and the
  # mapping of a referentiel, which has an editor of its own.
  HIDDEN_OPTIONS = [:old_pj, :skip_pj_validation, :skip_content_type_pj_validation, :referentiel_mapping].freeze

  def self.option_keys(type_champ)
    TypeDeChamp.find_sti_class(type_champ).option_keys - HIDDEN_OPTIONS
  end

  def initialize(procedure)
    @procedure = procedure
  end

  # The draft as the API describes a revision: the types de champ of the form,
  # the ones of the annotations, each list in its order, a repetition holding
  # its own. The header sections stay among their siblings, what they head
  # following them: the edits place a type de champ after another one, and a
  # section moves its heading alone. A condition reads in the format
  # set_condition takes.
  def describe
    type_de_champs = draft.type_de_champs

    describe_block = lambda do |block|
      block.map do |type_de_champ|
        {
          stable_id: type_de_champ.stable_id.to_s,
          type_champ: type_de_champ.type_champ,
          libelle: type_de_champ.libelle,
          description: type_de_champ.description,
          mandatory: type_de_champ.mandatory?,
          options: type_de_champ.clean_options.except(*HIDDEN_OPTIONS.map(&:to_s)),
          condition: describe_condition(type_de_champ.condition, type_de_champs),
          champs: (describe_block.call(type_de_champ.flat_children) if type_de_champ.repetition?),
        }.compact
      end
    end

    { champs: describe_block.call(draft.public_root_type_de_champs), annotations: describe_block.call(draft.private_root_type_de_champs) }
  end

  # The types the procedure may use, with what a client needs to pick one: the
  # options it takes, the blocks it goes in, whether a condition can read it.
  def type_champs
    TypeDeChamp.type_champ_classes
      .filter { it.feature_flag.nil? || procedure.feature_enabled?(it.feature_flag) }
      .map do |klass|
        type_champ = klass.sti_name

        {
          type_champ:,
          libelle: I18n.t(type_champ, scope: 'activerecord.attributes.type_de_champ.type_champs', app_name: APPLICATION_NAME, default: type_champ.humanize),
          options: self.class.option_keys(type_champ),
          allowed_in_repetition: klass.allowed_in_repetition?,
          private_only: klass.private_only?,
          public_only: klass.public_only?,
          condition_source: klass.conditionable?,
        }
      end
  end

  def add(type_champ:, libelle:, description: nil, mandatory: false, private: false, parent_stable_id: nil, after_stable_id: nil, options: nil)
    return Result.failure(unknown_type_champ(type_champ)) if !TypeDeChamp.type_champs.value?(type_champ)

    parent = find(parent_stable_id)
    if parent_stable_id.present?
      return Result.failure(not_found(parent_stable_id)) if parent.nil?
      return Result.failure("Le champ « #{parent.libelle} » n’est pas une répétition : il ne peut pas contenir d’autres champs.") if !parent.repetition?

      private = parent.private?
    end

    errors = type_champ_errors(type_champ, private:, child: parent.present?)
    errors += option_errors(type_champ, options)
    errors += after_errors(after_stable_id, repetition: parent, private:)
    return Result.failure(errors) if errors.present?

    params = { type_champ:, libelle:, description:, mandatory:, private:, parent_stable_id:, after_stable_id: }.compact
    type_de_champ = draft.add_type_de_champ(option_params(TypeDeChamp.find_sti_class(type_champ), options).merge(params))

    if type_de_champ.persisted? && type_de_champ.errors.empty?
      Result.success(type_de_champ.stable_id)
    else
      Result.failure(type_de_champ.errors.full_messages)
    end
  end

  def update(stable_id, libelle: nil, description: nil, mandatory: nil, type_champ: nil, options: nil)
    type_de_champ = find(stable_id)
    return Result.failure(not_found(stable_id)) if type_de_champ.nil?

    changing_type = type_champ.present? && type_champ != type_de_champ.type_champ
    target_type_champ = changing_type ? type_champ : type_de_champ.type_champ

    errors = changing_type ? type_change_errors(type_de_champ, type_champ) : []
    # against the type the champ ends up with: a type and its options can be set at once
    errors += option_errors(target_type_champ, options) if errors.empty?
    return Result.failure(errors) if errors.present?

    params = { libelle:, description:, mandatory: }.compact
    params[:type_champ] = type_champ if changing_type
    return Result.failure("Aucune modification demandée.") if params.empty? && options.blank?

    preserving_conditions do
      type_de_champ = draft.find_and_ensure_exclusive_use(stable_id)
      type_de_champ = type_de_champ.becomes_type(type_champ) if changing_type
      params = option_params(type_de_champ.class, options, current: type_de_champ.options).merge(params)

      if draft.update_type_de_champ(type_de_champ, params)
        Result.success(stable_id)
      else
        Result.failure(type_de_champ.errors.full_messages)
      end
    end
  rescue ActiveRecord::RecordNotFound
    Result.failure(not_found(stable_id))
  end

  # Right after another type de champ of the same block, or first in its block
  # without one.
  def move(stable_id, after_stable_id: nil)
    type_de_champ = find(stable_id)
    return Result.failure(not_found(stable_id)) if type_de_champ.nil?
    return Result.failure("Un champ ne peut pas être déplacé après lui-même.") if stable_id.to_s == after_stable_id.to_s

    errors = after_errors(after_stable_id, repetition: type_de_champ.enclosing_repetition, private: type_de_champ.private?)
    return Result.failure(errors) if errors.present?

    preserving_conditions do
      moved = if after_stable_id.present?
        draft.move_type_de_champ_after(stable_id, after_stable_id)
      else
        draft.move_type_de_champ(stable_id, 0)
      end

      moved.present? ? Result.success(stable_id) : Result.failure(not_found(stable_id))
    end
  end

  def remove(stable_id)
    type_de_champ = find(stable_id)
    return Result.failure(not_found(stable_id)) if type_de_champ.nil?
    return Result.failure(type_de_champ.deletion_locked_message) if type_de_champ.type_champ_locked?

    # The editor lets it go and shows the broken conditions; a client that does
    # not look at the form afterwards is told before.
    dependents = draft.type_de_champs.filter { it.condition? && it.condition.sources.include?(type_de_champ.stable_id) }
    if dependents.present?
      libelles = dependents.map { "« #{it.libelle} » (#{it.stable_id})" }.to_sentence
      return Result.failure("« #{type_de_champ.libelle} » est utilisé par la condition d’affichage de #{libelles} : retirez ou modifiez d’abord cette condition.")
    end

    draft.remove_type_de_champ(stable_id).present? ? Result.success(stable_id) : Result.failure(not_found(stable_id))
  end

  # terms: [{ source_stable_id:, operator:, value:, source_column: (optional) }]
  # No term removes the condition.
  def set_condition(stable_id, terms:, operator: 'and')
    return Result.failure(not_found(stable_id)) if find(stable_id).nil?

    top_operator = TOP_OPERATORS[operator.to_s.downcase]
    return Result.failure("L’opérateur « #{operator} » est inconnu. Opérateurs acceptés : #{TOP_OPERATORS.keys.join(', ')}.") if top_operator.nil?

    type_de_champ = draft.find_and_ensure_exclusive_use(stable_id)
    sources = type_de_champ.condition_source_type_de_champs

    conditions, errors = build_conditions(terms.map { it.to_h.symbolize_keys }, sources, conditioned: type_de_champ)
    return Result.failure(errors) if errors.present?

    condition = conditions.many? ? top_operator.new(conditions) : conditions.first
    errors = condition.present? ? condition_errors(condition, sources) : []
    return Result.failure(errors) if errors.present?

    type_de_champ.update!(condition:)
    Result.success(stable_id)
  rescue ActiveRecord::RecordNotFound
    Result.failure(not_found(stable_id))
  end

  private

  attr_reader :procedure

  def draft = procedure.draft_revision

  # The type de champ as the draft lays it out: it knows its repetition, its
  # siblings, what it is used by.
  def find(stable_id)
    draft.type_de_champ(stable_id) if Integer(stable_id.to_s, exception: false)
  end

  def not_found(stable_id) = "Le champ « #{stable_id} » n’existe pas dans le brouillon de cette démarche."

  def unknown_type_champ(type_champ) = "Le type de champ « #{type_champ} » n’existe pas."

  # What the type selector of the editor filters out of its menu.
  def type_champ_errors(type_champ, private:, child:)
    klass = TypeDeChamp.find_sti_class(type_champ)

    if klass.feature_flag.present? && !procedure.feature_enabled?(klass.feature_flag)
      ["Le type de champ « #{type_champ} » n’est pas activé sur cette démarche."]
    elsif child && !klass.allowed_in_repetition?
      ["Le type de champ « #{type_champ} » ne peut pas être utilisé dans une répétition."]
    elsif private && klass.public_only?
      ["Le type de champ « #{type_champ} » ne peut pas être utilisé dans les annotations privées."]
    elsif !private && klass.private_only?
      ["Le type de champ « #{type_champ} » ne peut être utilisé que dans les annotations privées."]
    else
      []
    end
  end

  def type_change_errors(type_de_champ, type_champ)
    return [unknown_type_champ(type_champ)] if !TypeDeChamp.type_champs.value?(type_champ)
    return [type_de_champ.type_change_locked_message] if type_de_champ.type_champ_locked?

    published_type_champ = procedure.published_revision&.type_de_champs&.find { it.stable_id == type_de_champ.stable_id }&.type_champ
    if published_type_champ.present?
      # the same matrix as the type selector of the editor: the answers of the
      # dossiers already filed must remain readable in the new type
      accepted = ([published_type_champ] + TypesDeChampEditor::TypeDeChampSelectorComponent::ACCEPTED_TYPES.fetch(published_type_champ, [])).uniq
      if !accepted.include?(type_champ)
        return ["« #{type_de_champ.libelle} » est déjà publié : son type ne peut devenir que #{accepted.join(', ')}, pour que les dossiers déposés restent lisibles."]
      end
    end

    type_champ_errors(type_champ, private: type_de_champ.private?, child: type_de_champ.in_repetition?)
  end

  def option_errors(type_champ, options)
    return [] if options.blank?
    return ["Les options doivent être un objet (clé/valeur)."] if !options.respond_to?(:to_h) || options.is_a?(Array)

    allowed = self.class.option_keys(type_champ).map(&:to_s)
    unknown = options.to_h.keys.map(&:to_s) - allowed
    if unknown.present?
      return ["Options inconnues pour le type « #{type_champ} » : #{unknown.join(', ')}. Options acceptées : #{allowed.presence&.join(', ') || 'aucune'}."]
    end

    option_value_errors(options.to_h.stringify_keys)
  end

  # What the editor form cannot send, a select offering the valid values only,
  # and that the model therefore does not validate.
  def option_value_errors(options)
    levels = 1..TypesDeChampEditor::HeaderSectionComponent::MAX_LEVEL
    level = options['header_section_level']

    if level.present? && !levels.cover?(Integer(level.to_s, exception: false))
      ["Le niveau de titre « #{level} » n’existe pas : header_section_level va de #{levels.first} à #{levels.last}."]
    else
      []
    end
  end

  # The options go through the writers of the type, as the editor form sends
  # them. A type that reads some of its options from the jsonb without a writer
  # (the layers of a carte) gets them all merged there, as its own editor does:
  # a writer called next to an assignment of the jsonb is lost on a new record.
  def option_params(klass, options, current: {})
    return {} if options.blank?

    options = options.to_h.transform_keys(&:to_sym)

    if self.class.option_keys(klass.sti_name).all? { klass.method_defined?(:"#{it}=") }
      options
    else
      { options: (current || {}).to_h.merge(options.stringify_keys) }
    end
  end

  def after_errors(after_stable_id, repetition:, private:)
    return [] if after_stable_id.blank?

    after = find(after_stable_id)
    return [not_found(after_stable_id)] if after.nil?

    if after.enclosing_repetition&.stable_id != repetition&.stable_id || after.private? != private
      ["Le champ « #{after_stable_id} » n’est pas dans le même bloc : un champ se place après un champ du même formulaire (usager ou annotations privées) et de la même répétition."]
    else
      []
    end
  end

  def describe_condition(condition, type_de_champs)
    return nil if condition.nil?

    operator, operands = case condition
    when Logic::Or then ['or', condition.operands]
    when Logic::And then ['and', condition.operands]
    else ['and', [condition]]
    end

    # a row the editor left empty is no term
    terms = operands.filter_map { describe_term(it, type_de_champs) }

    { operator:, terms: } if terms.present?
  end

  def describe_term(operand, type_de_champs)
    operator = OPERATOR_NAMES[operand.class.name]
    return nil if operator.nil?

    left = operand.left
    return nil if !left.respond_to?(:stable_id)

    {
      source_stable_id: left.stable_id.to_s,
      source_column: (left.to_h['column_id'] if left.is_a?(Logic::ChampColumnValue)),
      source_libelle: type_de_champs.find { it.stable_id == left.stable_id }&.libelle,
      operator:,
      value: operand.right.is_a?(Logic::Constant) ? operand.right.value.to_s : '',
    }.compact
  end

  def build_conditions(terms, sources, conditioned:)
    errors = []

    conditions = terms.filter_map do |term|
      operator_class = OPERATORS[term[:operator].to_s]
      source = sources.find { it.stable_id.to_s == term[:source_stable_id].to_s }

      if operator_class.nil?
        errors << "L’opérateur « #{term[:operator]} » est inconnu. Opérateurs acceptés : #{OPERATORS.keys.join(', ')}."
      elsif source.nil?
        errors << unavailable_source(term[:source_stable_id], conditioned)
      else
        left = if term[:source_column].present?
          Logic::ChampColumnValue.new(source.stable_id, term[:source_column])
        else
          Logic::ChampValue.new(source.stable_id)
        end

        operator_class.new(left, constant(left.type(sources), term[:value]))
      end
    end

    [conditions, errors]
  end

  # A client sends every value as it reads it; the type of the source says how
  # the condition compares it.
  def constant(left_type, value)
    case left_type
    when :boolean
      # anything else stays a string, for the condition to refuse it
      Logic::Constant.new({ 'true' => true, 'false' => false }.fetch(value.to_s.downcase, value.to_s))
    when :number
      number = Float(value.to_s, exception: false)
      Logic::Constant.new(number.nil? ? value.to_s : (number % 1 == 0 ? number.to_i : number))
    else
      Logic::Constant.new(value.to_s)
    end
  end

  # Why a type de champ cannot be read by the condition of another.
  def unavailable_source(source_stable_id, conditioned)
    source = find(source_stable_id)
    return not_found(source_stable_id) if source.nil?

    name = "« #{source.libelle} » (#{source.stable_id})"
    repetition = source.enclosing_repetition

    if repetition.present? && repetition.stable_id != conditioned.enclosing_repetition&.stable_id
      "#{name} est dans la répétition « #{repetition.libelle} » : il ne peut conditionner que des champs de cette répétition."
    elsif source.private? && conditioned.public?
      "#{name} est une annotation privée : elle ne peut pas conditionner un champ du formulaire usager."
    else
      "#{name} ne peut pas être la source de cette condition : la source doit être placée avant « #{conditioned.libelle} »."
    end
  end

  # The types de champ whose condition no longer holds together: a source gone,
  # moved after it, or of a type or with options the comparison does not fit.
  # Read from the database: the edit just made is not in the loaded revision.
  def broken_conditions
    ProcedureRevision.find(draft.id).type_de_champs.filter_map do |type_de_champ|
      next if !type_de_champ.condition?

      sources = type_de_champ.condition_source_type_de_champs
      [type_de_champ.stable_id, type_de_champ.libelle] if type_de_champ.condition.errors(sources).present?
    end.to_h
  end

  # The editor lets an edit break the condition of another type de champ, and
  # shows it broken. A client that does not look at the form afterwards has
  # the edit undone, and is told which condition to deal with first.
  def preserving_conditions
    already_broken = broken_conditions
    result = nil

    ActiveRecord::Base.transaction do
      result = yield
      next if !result.success?

      broken = broken_conditions.except(*already_broken.keys)
      if broken.present?
        libelles = broken.map { |stable_id, libelle| "« #{libelle} » (#{stable_id})" }.to_sentence
        result = Result.failure("Cette modification rendrait invalide la condition d’affichage de #{libelles} : modifiez ou retirez d’abord cette condition.")
        raise ActiveRecord::Rollback
      end
    end

    # the revision in memory has seen an edit the database has not kept
    procedure.draft_revision.reload if !result.success?

    result
  end

  # Worded as the editor words them: the component translates with its own
  # locale file, which it reads once rendered.
  def condition_errors(condition, sources)
    component = Conditions::ConditionsErrorsComponent.new(condition:, source_tdcs: sources)
    component.render_in(ApplicationController.new.view_context)
    component.messages
  end
end
