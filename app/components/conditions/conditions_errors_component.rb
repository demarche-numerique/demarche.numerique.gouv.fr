# frozen_string_literal: true

class Conditions::ConditionsErrorsComponent < ApplicationComponent
  def initialize(condition:, source_tdcs:)
    @condition, @source_tdcs = condition, source_tdcs
  end

  private

  def errors = to_html_list(messages)

  def messages
    @messages ||= begin
      errors = @condition ? Logic.errors(@condition, @source_tdcs).uniq : []

      # if a tdc is not available (has been removed for example)
      # it causes a lot of errors (incompatible type for example)
      # only the root cause is displayed
      if errors.include?({ type: :not_available })
        [t('not_available', scope: '.errors')]
      else
        errors.filter_map { |error| humanize(error) }
      end
    end
  end

  def to_html_list(messages)
    messages
      .map { |message| tag.li(message) }
      .then { |lis| tag.ul(lis.reduce(&:+)) }
  end

  def humanize(error)
    case error
    in { type: :not_available }
    in { type: :incompatible, stable_id: nil }
      t('not_available', scope: '.errors')
    in { type: :unmanaged, stable_id: stable_id }
      targeted_champ = @source_tdcs.find { |tdc| tdc.stable_id == stable_id }
      t('unmanaged',
        scope: '.errors',
        libelle: targeted_champ.libelle,
        type_champ: t(targeted_champ.type_champ, scope: 'activerecord.attributes.type_de_champ.type_champs')&.downcase)
    in { type: :incompatible, stable_id: stable_id, right: right, operator_name: operator_name }
      targeted_champ = @source_tdcs.find { |tdc| tdc.stable_id == stable_id }
      t('incompatible', scope: '.errors',
        libelle: targeted_champ.libelle,
        type_champ: t(targeted_champ.type_champ, scope: 'activerecord.attributes.type_de_champ.type_champs')&.downcase,
        operator: t(operator_name, scope: 'logic.operators').downcase,
        right: right.to_s.downcase)
    in { type: :required_number, operator_name: operator_name }
      t('required_number', scope: '.errors',
        operator: t(operator_name, scope: 'logic.operators'))
    in { type: :not_included, stable_id: stable_id, right: right }
      targeted_champ = @source_tdcs.find { |tdc| tdc.stable_id == stable_id }
      t('not_included', scope: '.errors',
        libelle: targeted_champ.libelle,
        right: right.to_s.downcase)
    in { type: :required_list }
      t('required_list', scope: '.errors')
    in { type: :required_include, operator_name: "Logic::Eq" }
      t("required_include.eq", scope: '.errors')
    in { type: :required_include, operator_name: "Logic::NotEq" }
      t("required_include.not_eq", scope: '.errors')
    in { type: :empty_options, stable_id: stable_id }
      targeted_champ = @source_tdcs.find { |tdc| tdc.stable_id == stable_id }
      t('empty_options', scope: '.errors',
        libelle: targeted_champ.libelle)
    in { type: :contradiction, stable_id: stable_id, atoms: atoms }
      targeted_champ = @source_tdcs.find { |tdc| tdc.stable_id == stable_id }
      t('contradiction', scope: '.errors',
        count: atoms.size,
        libelle: targeted_champ.libelle,
        atoms: atoms.map { humanize_atom(it) }.to_sentence)
    in { type: :unreachable, stable_id: stable_id }
      targeted_champ = @source_tdcs.find { |tdc| tdc.stable_id == stable_id }
      t('unreachable', scope: '.errors', libelle: targeted_champ.libelle)
    else
      nil
    end
  end

  def humanize_atom(atom)
    "#{t(atom.class.name, scope: 'logic.operators').downcase} « #{humanize_value(atom)} »"
  end

  # The label the admin picked (a region name, a departement, a choice) rather
  # than the value stored behind it
  def humanize_value(atom)
    label, _value = atom.left.options(@source_tdcs, atom.class.name)&.find { |_label, value| value == atom.right.value }

    label || atom.right.to_s.downcase
  end

  def render? = messages.present?
end
