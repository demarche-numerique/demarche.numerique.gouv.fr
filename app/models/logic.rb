# frozen_string_literal: true

module Logic
  def self.from_h(h)
    class_from_name(h['term']).from_h(h)
  end

  def self.from_json(s)
    from_h(JSON.parse(s))
  end

  def self.class_from_name(name)
    [
      ChampValue,
      ChampColumnValue,
      Constant,
      Empty,
      LessThan,
      LessThanEq,
      Eq,
      NotEq,
      GreaterThanEq,
      GreaterThan,
      EmptyOperator,
      IncludeOperator,
      ExcludeOperator,
      And,
      Or,
      InDepartementOperator,
      NotInDepartementOperator,
      InRegionOperator,
      NotInRegionOperator,
    ].find { |c| c.name == name }
  end

  # Public expression format: prefix notation encoded as JSON arrays, e.g.
  #   ["and", ["=", ["champ", "Q2hhbXAtMQ=="], "option"], [">=", ["champ", "Q2hhbXAtMg=="], 18]]
  # Champs are referenced by their ChampDescriptor id (the typed stable_id),
  # constants are plain JSON values and the empty term is null.
  EXPR_OPERATORS = {
    Eq => '=',
    NotEq => '!=',
    LessThan => '<',
    LessThanEq => '<=',
    GreaterThan => '>',
    GreaterThanEq => '>=',
    EmptyOperator => 'empty?',
    IncludeOperator => 'includes',
    ExcludeOperator => 'excludes',
    InDepartementOperator => 'in-departement',
    NotInDepartementOperator => 'not-in-departement',
    InRegionOperator => 'in-region',
    NotInRegionOperator => 'not-in-region',
    And => 'and',
    Or => 'or',
  }.freeze

  EXPR_CHAMP = 'champ'
  EXPR_COLUMN = 'column'

  def self.from_expr(expr)
    case expr
    in nil
      Empty.new
    in String | Numeric | true | false
      Constant.new(expr)
    in [EXPR_CHAMP, String => id]
      ChampValue.new(stable_id_from_expr(id))
    in [EXPR_COLUMN, String => id, String => column_id]
      ChampColumnValue.new(stable_id_from_expr(id), column_id)
    in [String => operator, *operands]
      operator_class = EXPR_OPERATORS.key(operator)
      raise ArgumentError, "unknown operator #{operator.inspect}" if operator_class.nil?

      if operator_class < NAryOperator
        operator_class.new(operands.map { from_expr(it) })
      elsif operands.size == 2
        operator_class.new(from_expr(operands[0]), from_expr(operands[1]))
      else
        raise ArgumentError, "#{operator} expects 2 operands, got #{operands.size}"
      end
    else
      raise ArgumentError, "invalid expression #{expr.inspect}"
    end
  end

  def self.champ_expr_id(stable_id)
    GraphQL::Schema::UniqueWithinType.encode('Champ', stable_id)
  end

  def self.stable_id_from_expr(id)
    type_name, stable_id = GraphQL::Schema::UniqueWithinType.decode(id)
    raise ArgumentError, "invalid champ reference #{id.inspect}" if type_name != 'Champ' || stable_id.blank?

    stable_id.to_i
  rescue GraphQL::ExecutionError
    raise ArgumentError, "invalid champ reference #{id.inspect}"
  end

  # Lisp-like rendering of an expression: (and (= (champ "…") "option") (>= (champ "…") 18))
  def self.to_sexp(expr)
    case expr
    in nil
      'nil'
    in [String => head, *args]
      "(#{[head, *args.map { to_sexp(it) }].join(' ')})"
    in String
      JSON.generate(expr)
    else
      expr.to_s
    end
  end

  def self.ensure_compatibility_from_left(condition, type_de_champs)
    left = condition.left
    right = condition.right
    operator_class = condition.class

    case [left.type(type_de_champs), condition]
    in [:boolean, _]
      operator_class = Eq
    in [:empty, _]
      operator_class = EmptyOperator
    in [:enum, _]
      operator_class = Eq
    in [:commune_enum, _] | [:epci_enum, _] | [:address, _]
      operator_class = InDepartementOperator
    in [:departement_enum, _]
      operator_class = Eq
    in [:enums, _]
      operator_class = IncludeOperator
    in [:number, EmptyOperator]
      operator_class = Eq
    in [:number, _]
    end

    if !compatible_type?(left, right, type_de_champs)
      right = case left.type(type_de_champs)
      when :boolean
        Constant.new(true)
      when :empty
        Empty.new
      when :enum, :enums, :commune_enum, :epci_enum, :departement_enum, :address
        if left.options(type_de_champs).blank?
          Empty.new
        else
          Constant.new(left.options(type_de_champs).first.second)
        end
      when :number
        Constant.new(0)
      end
    end

    operator_class.new(left, right)
  end

  def self.compatible_type?(left, right, type_de_champs)
    case [left.type(type_de_champs), right.type(type_de_champs)]
    in [a, ^a] # syntax for same type
      true
    in [:enum, :string] | [:enums, :string] | [:commune_enum, :string] | [:epci_enum, :string] | [:departement_enum, :string] | [:address, :string]
      true
    else
      false
    end
  end

  def self.add_empty_condition_to(condition)
    empty_condition = EmptyOperator.new(Empty.new, Empty.new)

    if condition.nil?
      empty_condition
    elsif [And, Or].include?(condition.class)
      condition.tap { |c| c.operands << empty_condition }
    else
      Logic::And.new([condition, empty_condition])
    end
  end

  def self.split_condition(condition)
    [condition.left, condition.class.name, condition.right]
  end

  def ds_eq(left, right) = Logic::Eq.new(left, right)

  def ds_not_eq(left, right) = Logic::NotEq.new(left, right)

  def greater_than(left, right) = Logic::GreaterThan.new(left, right)

  def greater_than_eq(left, right) = Logic::GreaterThanEq.new(left, right)

  def less_than(left, right) = Logic::LessThan.new(left, right)

  def less_than_eq(left, right) = Logic::LessThanEq.new(left, right)

  def ds_include(left, right) = Logic::IncludeOperator.new(left, right)

  def ds_in_departement(left, right) = Logic::InDepartementOperator.new(left, right)

  def ds_not_in_departement(left, right) = Logic::NotInDepartementOperator.new(left, right)

  def ds_in_region(left, right) = Logic::InRegionOperator.new(left, right)

  def ds_not_in_region(left, right) = Logic::NotInRegionOperator.new(left, right)

  def ds_exclude(left, right) = Logic::ExcludeOperator.new(left, right)

  def constant(value) = Logic::Constant.new(value)

  def champ_value(stable_id) = Logic::ChampValue.new(stable_id)

  def champ_column_value(column) = Logic::ChampColumnValue.new(column.stable_id, column.column_id)

  def empty = Logic::Empty.new

  def empty_operator(left, right) = Logic::EmptyOperator.new(left, right)

  def ds_or(operands) = Logic::Or.new(operands)

  def ds_and(operands) = Logic::And.new(operands)
end
